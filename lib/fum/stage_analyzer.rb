module Fum

  #
  # Analyzes environments and DNS zone info to determine which environments belong to a particular stage
  # and the status of each environment.
  #
  class StageAnalyzer
    include Fum::DNS

    attr_accessor :env_map, :zones_map

    def initialize(stage_decl)
      @stage_decl = stage_decl
      @zones_map = {}
      @env_map = {}
    end

    def analyze(options)
      beanstalk = Fog::AWS[:beanstalk]
      build_zone_map(@stage_decl.zones, options)
      analyze_zone_map(beanstalk.environments.select { |env| @stage_decl.matches?(env) }, options)
      analyze_cname()
      @env_map
    end

    # Return the Active environment or nil
    def active
      @env_map.values.select { |e| e[:state] == :active }.map { |e| e[:env] }.shift
    end

    # Return the inactive environments or empty array
    def inactive
      @env_map.values.select { |e| e[:state] == :inactive }.map { |e| e[:env] }
    end

    private

    def analyze_cname
      cname_prefix = @stage_decl.cname
      if cname_prefix
        env_map.each { |key, value|
          if value[:env].cname.start_with?(cname_prefix + ".")
            if @zones_map.size > 0
            else
              value[:state] = :active
            end
          end
        }
      end
    end

    #
    # Build Map
    #
    def build_zone_map(zone_decls, options)
      zone_decls.each { |zone_decl|
        puts "Looking up zone #{zone_decl.name}." if Fum.verbose
        zones = dns.zones.all
        zone = zones.select { |z| z.domain == ensure_trailing_dot(zone_decl.name)}.shift
        Fum::die "Could not find zone #{zone_decl.name} in account." unless zone

        puts "Obtaining all records for zone #{zone_decl.name}" if Fum.verbose
        all_records = zone.records.all!

        zone_decl.records.each { |record_decl|
          fqdn = fqdn_for_record_decl(record_decl, zone_decl)

          existing = all_records.select { |r| r.name == fqdn && ['A', 'AAAA', 'CNAME'].include?(r.type)}

          if existing.length > 1
            # We do not currently handle this case, which would occur if AAAA records exist or weighted/latency records used.
            Fum::die "Cannot update record #{fqdn} in zone #{zone} because more than one A, AAAA, or CNAME record already exists."
          end

          @zones_map[fqdn] = {
              :zone_decl => zone_decl,
              :record_decl => record_decl,
              :record => existing.shift
          }
        }

      }
    end

    def fqdn_for_record_decl(record_decl, zone_decl)
      fqdn = ""
      fqdn += "#{record_decl[:name]}." unless record_decl[:name] == :apex
      fqdn += "#{zone_decl.name}."
      fqdn
    end

    def analyze_zone_map(environments, options)
      puts "Analyzing environments." if Fum.verbose

      environments.each { |e|
        @env_map[e.id] = {
            :env => e,
            :elb => e.ready? ? e.load_balancer : nil,
            :record_count => 0,
            :dns_records => [],
            :missing_dns_names => [],
            :state => e.ready? ? :inactive : e.status.downcase.to_sym,
            :environment => nil
        }
      }

      @zones_map.each { |fqdn, entry|
        next if entry[:record].nil?

        if entry[:record].type != entry[:record_decl][:type]
          entry[:error] = "incorrect record type #{entry[:record].type}"
          entry[:environment] = nil
          next
        end

        entry[:environment] = case entry[:record_decl][:type]
                                when "A"
                                  environment_for_alias(entry[:record])
                                when "CNAME"
                                  case entry[:record_decl][:target]
                                    when :elb
                                      environment_for_elb_cname(entry[:record])
                                    when :env
                                      environment_for_cname(entry[:record])
                                  end
                                else
                                  nil
                              end

        if entry[:environment]
          @env_map[entry[:environment].id][:record_count] += 1
        end
      }

      zone_count = @zones_map.size

      envs_with_records = @env_map.values.select { |e| e[:record_count] > 0 }

      if envs_with_records.length == 1
        record = envs_with_records.shift
        if record[:record_count] == zone_count
          record[:state] = :active
        else
          record[:state] = :degraded
        end
      else
        # More than one record has DNS records, let's determine which ones
        envs_with_records.each { |e|
          e[:state] = :indeterminate
        }
      end

    end

    def environment_for_alias(record)
      return nil unless record.alias_target

      @env_map.each_value { |e|
        next unless e[:env].ready? # Skip if environment not ready.
        if e[:elb] && dns_names_equal(e[:elb].dns_name, record.alias_target['DNSName']) &&
            e[:elb].hosted_zone_name_id == record.alias_target['HostedZoneId']
          return e[:env]
        end
      }
      nil
    end

    def environment_for_elb_cname(record)
      dns_name = record.value.shift

      @env_map.each_value { |e|
        next unless e[:env].ready? # Skip if environment not ready.
        if e[:elb] && dns_names_equal(e[:elb].dns_name, dns_name)
          return e[:env]
        end
      }
      nil
    end

    def environment_for_cname(record)
      dns_name = record.value.shift

      @env_map.each_value { |e|
        next unless e[:env].ready? # Skip if environment not ready.
        if dns_names_equal(e[:env].cname, dns_name)
          return e[:env]
        end
      }
      nil
    end

  end

end