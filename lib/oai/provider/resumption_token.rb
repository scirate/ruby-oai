require 'time'
require 'enumerator'
require File.dirname(__FILE__) + "/partial_result"

module OAI::Provider
  
  class ResumptionToken
    attr_reader :prefix, :set, :from, :until, :last, :expiration, :total

    def initialize(options, expiration = nil, total = nil)
      @prefix = options[:metadata_prefix]
      @set = options[:set]
      @last = options[:last]
      @from = options[:from] if options[:from]
      @until = options[:until] if options[:until]
      @expiration = expiration if expiration
      @total = total if total
    end
      
    def self.parse(token_string)
      begin
        options = {}
        matches = /(.+):(\d+)$/.match(token_string)
        options[:last] = matches.captures[1].to_i
        
        parts = matches.captures[0].split('.')
        options[:metadata_prefix] = parts.shift
        parts.each do |part|
          case part
          when /^s/
            options[:set] = part.sub(/^s\(/, '').sub(/\)$/, '')
          when /^f/
            options[:from] = Time.parse(part.sub(/^f\(/, '').sub(/\)$/, '')).localtime
          when /^u/
            options[:until] = Time.parse(part.sub(/^u\(/, '').sub(/\)$/, '')).localtime
          end
        end
        self.new(options)
      rescue => err
        raise ResumptionTokenException.new
      end
    end
    
    def self.extract_format(token_string)
      return token_string.split('.')[0]
    end
    
    def next(last)
      @last = last
      self
    end
    
    def ==(other)
      prefix == other.prefix and set == other.set and from == other.from and
        self.until == other.until and last == other.last and 
        expiration == other.expiration and total == other.total
    end
    
    def to_xml
      xml = Builder::XmlMarkup.new
      xml.resumptionToken(encode_conditions, hash_of_attributes)
      xml.target!
    end
    
    def to_conditions_hash
      conditions = {:metadata_prefix => self.prefix }
      conditions[:set] = self.set if self.set
      conditions[:from] = self.from if self.from
      conditions[:until] = self.until if self.until
      conditions
    end
    
    def to_s
      encode_conditions.gsub(/:\w+?$/, '')
    end

    private
    
    def encode_conditions
      encoded_token = @prefix.to_s.dup
      encoded_token << ".s(#{set})" if set
      encoded_token << ".f(#{from.utc.xmlschema})" if from
      encoded_token << ".u(#{self.until.utc.xmlschema})" if self.until
      encoded_token << ":#{last}"
    end

    def hash_of_attributes
      attributes = {}
      attributes[:completeListSize] = self.total if self.total
      attributes[:expirationDate] = self.expiration.utc.xmlschema if self.expiration
      attributes
    end

    
  end
  
  module ResumptionHelpers
    
    def token(opts)
      return opts[:resumption_token]
    end
        
    def generate_chunks(records, limit)
      groups = []
      records.each_slice(limit) do |group|
        groups << group
      end
      groups
    end
        
  end
          
end