module Fum

  # Mixin for common DNS methods
  module DNS

    def dns
      Fog::DNS[:AWS]
    end

    def update_zones(stage_decl, env, options)
      zones = stage_decl.zones

      hosted_zone_name_id = nil
      dns_name = nil

      unless options[:noop]
        lb = env.load_balancer

        hosted_zone_name_id = lb.hosted_zone_name_id
        dns_name = lb.dns_name
      end

      zones.each { |zone| update_zone(zone, hosted_zone_name_id, dns_name, env.cname, options) }

    end

    def update_zone(zone_decl, hosted_zone_name_id, dns_name, env_cname, options)
      dns = Fog::DNS[:aws]

      zone = dns.zones.all.select {|z| z.domain == ensure_trailing_dot(zone_decl.name)}.shift
      die "Could not find zone #{zone_decl.name} in account." unless zone

      puts "Updating records in zone #{zone.domain}"

      create_list = []
      modify_list = []

      zone_decl.records.each { |record|
        fqdn = fqdn_for_record_decl(record, zone_decl)

        create_opts = {
            :name => fqdn,
            :type => record[:type]
        }

        case record[:type]
          when 'CNAME'
            create_opts[:value] = case record[:target]
                                    when :elb
                                      ensure_trailing_dot(dns_name)
                                    when :env
                                      ensure_trailing_dot(env_cname)
                                  end
          when 'A'
            create_opts[:alias_target] = {
                :hosted_zone_id => hosted_zone_name_id,
                :dns_name => dns_name
            }
          else
            raise RuntimeError, "Unknown type #{record[:type]}"
        end

        existing = find_records(zone, fqdn)

        if existing.length > 1
          # We do not currently handle this case, which would occur if AAAA records exist or weighted/latency records used.
          puts "Cannot update record #{fqdn} in zone #{zone} because more than one A, AAAA, or CNAME record already exists."
        end

        if existing.length == 0
          create_list << create_opts
        else
          modify_list << {
              :record => existing.shift,
              :create_opts => create_opts
          }
        end

      }

      # We do not currently do this atomically, but one record at a time.  Should probably move to atomic at some
      # point.

      new_records = []

      create_list.each { |create_options|
        puts "Creating #{create_options[:type]} record with name #{create_options[:name]} in zone #{zone.domain}"
        unless options[:noop]
          new_records << zone.records.create(create_options)
        end
      }

      modify_list.each { |record|
        puts "Updating #{record[:create_opts][:type]} record with name #{record[:create_opts][:name]} in zone #{zone.domain}"
        unless options[:noop]
          record[:record].modify(record[:create_opts])
          new_records << record[:record]
        end
      }

      puts "Waiting for DNS records to sync in zone #{zone.domain}..."
      # Wait for records to be ready.
      new_records.each { |record|
        record.wait_for { record.ready? }
      }
      puts "Updated records are now in sync in zone #{zone.domain}"

    end

    def fqdn_for_record_decl(record_decl, zone_decl)
      fqdn = ""
      fqdn += "#{record_decl[:name]}." unless record_decl[:name] == :apex
      fqdn += "#{zone_decl.name}."
      fqdn
    end

    def find_records(zone, name)
      existing_records = zone.records.all({:name => name})

      matching = []
      types = ['A', 'AAAA', 'CNAME']
      existing_records.each { |record|
        matching << record if record.name == name && types.include?(record.type)
      }
      matching
    end

    # Appends a trailing . to the given name if it doesn't have one
    def ensure_trailing_dot(name)
      name = "#{name}." unless name.nil? || name.end_with?(".")
      name
    end

    # Returns true if the specified dns names equal, ignoring any trailing "."
    def dns_names_equal(a, b)
      # ignore case and ensure trailing date for comparison
      ensure_trailing_dot(a).casecmp(ensure_trailing_dot(b)) == 0
    end

  end
end