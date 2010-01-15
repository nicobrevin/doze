require 'rest_on_rack/media_type'
require 'rest_on_rack/serialization/entity'
require 'rest_on_rack/error'
require 'rest_on_rack/utils'

module Rack::REST::Serialization
  # ripped off largely from Merb::Parse
  # Supports PHP-style nested hashes via foo[bar][baz]=boz
  class Entity::WWWFormEncoded < Entity
    def serialize(value, prefix=nil)
      case value
      when Array
        value.map {|v| serialize(v, "#{prefix}[]")}.join("&")
      when Hash
        value.map {|k,v| serialize(v, prefix ? "#{prefix}[#{escape(k)}]" : escape(k))}.join("&")
      else
        "#{prefix}=#{escape(value)}"
      end
    end

    def deserialize(data)
      query = {}
      for pair in data.split(/[&;] */n)
        key, value = unescape(pair).split('=',2)
        next if key.nil?
        if key.include?('[')
          normalize_params(query, key, value)
        else
          query[key] = value
        end
      end
      query
    end

    def escape(s)
      s.to_s.gsub(/([^ a-zA-Z0-9_.-]+)/n) {
        '%'+$1.unpack('H2'*$1.size).join('%').upcase
      }.tr(' ', '+')
    end

    def unescape(s)
      s.tr('+', ' ').gsub(/((?:%[0-9a-fA-F]{2})+)/n){
        [$1.delete('%')].pack('H*')
      }
    end

    def normalize_params(parms, name, val=nil)
      name =~ %r([\[\]]*([^\[\]]+)\]*)
      key = $1 || ''
      after = $' || ''

      if after == ""
        parms[key] = val
      elsif after == "[]"
        (parms[key] ||= []) << val
      elsif after =~ %r(^\[\]\[([^\[\]]+)\]$)
        child_key = $1
        parms[key] ||= []
        if parms[key].last.is_a?(Hash) && !parms[key].last.key?(child_key)
          parms[key].last.update(child_key => val)
        else
          parms[key] << { child_key => val }
        end
      else
        parms[key] ||= {}
        parms[key] = normalize_params(parms[key], after, val)
      end
      parms
    end
  end

  # A browser-friendly media type for use with Rack::REST::Serialization::Resource.
  WWW_FORM_ENCODED = Rack::REST::MediaType.register('application/x-www-form-urlencoded', :entity_class => Entity::WWWFormEncoded)
end
