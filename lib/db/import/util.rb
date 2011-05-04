module Aurora
  module ImportUtil
    # Elements that are referenced from other elements in the xml.
    REFERENCED_ELEMENT_TYPES = %w{ network node link }

    # Elements that are not referenced from other elements in the xml.
    UNREFERENCED_ELEMENT_TYPES =
      %w{ scenario sensor monitor
          InitialDensityProfile SplitRatioProfileSet CapacityProfileSet
          EventSet DemandProfileSet ControllerSet }

    class << self
      def numeric(str)
        str && Integer(str) rescue nil
      end

      # Operates destructively on a scenario element and its descendants.
      # Every node, link, etc. with a numeric ID is assigned a non-numeric ID
      # that is unique among existing as well as newly assigned IDs. Updates
      # each reference to the node, link, etc. to use the new ID.
      # Unreferenced element types that have numeric IDs can simply be assigned
      # a null ID.
      def rekey scenario_xml
        UNREFERENCED_ELEMENT_TYPES.each do |t|
          scenario_xml.xpath("//#{t}").each do |elt|
            elt["id"] = "" if numeric(elt["id"])
          end
        end

        # the network's network_id is also unreferenced
        scenario_xml.xpath("//network").each do |elt|
          elt["network_id"] = "" if numeric(elt["network_id"])
        end

        REFERENCED_ELEMENT_TYPES.each do |t|
          rekey_for_type t, scenario_xml
        end
      end

      def rekey_for_type t, scenario_xml
        num_id_elt = {} # int => elt
        tmp_id_elt = {} # str => elt

        scenario_xml.xpath("//#{t}").each do |elt|
          id = numeric(elt["id"])
          (id ? num_id_elt : tmp_id_elt)[id] = elt
        end

        delta = make_tmp_ids(num_id_elt, tmp_id_elt)

        ref_attr = "#{t}_id"
        scenario_xml.xpath("//*").each do |ref_elt|
          id = numeric(ref_elt[ref_attr])
          if id
            elt = num_id_elt[id]
            if elt
              ref_elt[ref_attr] = delta[id]
            else
              warn "broken reference in #{ref_elt.name} to #{ref_attr}=#{id}"
            end
          end
        end
      end

      def make_tmp_ids num_id_elt, tmp_id_elt
        u = 1
        uniq_in_hash = proc do |h,k|
          new_key = "new_#{k}_#{u}"
          while h[new_key]
            u += 1
            new_key = "new_#{k}_#{u}"
          end
          new_key
        end

        delta = {}

        num_id_elt.each do |id, elt|
          new_tmp_id = uniq_in_hash[tmp_id_elt, id]
          tmp_id_elt[new_tmp_id] = elt
          elt["id"] = new_tmp_id
          delta[id] = new_tmp_id
        end

        delta
      end
    end
  end
end
