# frozen_string_literal: true

if defined?(RSpec)
  RSpec::Matchers.define :have_deprecated do |deprecation|
    match do |actual|
      # Suppresses logging output to stdout while ensuring that it is still happening
      default_output = Selenium::WebDriver.logger.io
      io = StringIO.new
      Watir.logger.output = io

      actual.call

      Watir.logger.output = default_output
      @deprecations_found = (io.rewind && io.read).scan(/DEPRECATION\] \[:([^\]]*)\]/).flatten.map(&:to_sym)
      expect(Array(deprecation).sort).to eq(@deprecations_found.sort)
    end

    failure_message do
      but_message = if @deprecations_found.nil? || @deprecations_found.empty?
                      'no deprecations were found'
                    else
                      "instead these deprecations were found: [#{@deprecations_found.join(', ')}]"
                    end
      "expected :#{deprecation} to have been deprecated, but #{but_message}"
    end

    failure_message_when_negated do
      but_message = "it was found among these deprecations: [#{@deprecations_found.join(', ')}]"
      "expected :#{deprecation} not to have been deprecated, but #{but_message}"
    end

    def supports_block_expectations?
      true
    end
  end

  TIMING_EXCEPTIONS = {
    unknown_object: Watir::Exception::UnknownObjectException,
    no_matching_window: Watir::Exception::NoMatchingWindowFoundException,
    unknown_frame: Watir::Exception::UnknownFrameException,
    object_disabled: Watir::Exception::ObjectDisabledException,
    object_read_only: Watir::Exception::ObjectReadOnlyException,
    no_value_found: Watir::Exception::NoValueFoundException,
    timeout: Watir::Wait::TimeoutError
  }.freeze

  TIMING_EXCEPTIONS.each do |matcher, exception|
    RSpec::Matchers.define "raise_#{matcher}_exception" do |message|
      match do |actual|
        original_timeout = Watir.default_timeout
        Watir.default_timeout = 0
        begin
          actual.call
          false
        rescue exception => e
          return true if message.nil? || e.message.match(message)

          raise exception, "expected '#{message}' to be included in: '#{e.message}'"
        ensure
          Watir.default_timeout = original_timeout
        end
      end

      failure_message do |_actual|
        "expected #{exception} but nothing was raised"
      end

      def supports_block_expectations?
        true
      end
    end

    RSpec::Matchers.define "wait_and_raise_#{matcher}_exception" do |message = nil, timeout: 2|
      match do |actual|
        original_timeout = Watir.default_timeout
        Watir.default_timeout = timeout
        begin
          start_time = Time.now
          actual.call
          false
        rescue exception => e
          finish_time = Time.now
          unless message.nil? || e.message.match(message)
            raise exception, "expected '#{message}' to be included in: '#{e.message}'"
          end

          @time_difference = finish_time - start_time
          @time_difference > timeout
        ensure
          Watir.default_timeout = original_timeout
        end
      end

      failure_message do
        if @time_difference
          "expected action to take more than provided timeout (#{timeout} seconds), " \
            "instead it took #{@time_difference} seconds"
        else
          "expected #{exception} but nothing was raised"
        end
      end

      def supports_block_expectations?
        true
      end
    end
  end

  RSpec::Matchers.define :execute_when_satisfied do |min: 0, max: nil|
    max ||= min + 1
    match do |actual|
      original_timeout = Watir.default_timeout
      Watir.default_timeout = max
      begin
        start_time = Time.now
        actual.call
        @time_difference = Time.now - start_time
        @time_difference > min && @time_difference < max
      ensure
        Watir.default_timeout = original_timeout
      end
    end

    failure_message_when_negated do
      "expected action to take less than #{min} seconds or more than #{max} seconds, " \
        "instead it took #{@time_difference} seconds"
    end

    failure_message do
      "expected action to take more than #{min} seconds and less than #{max} seconds, " \
        "instead it took #{@time_difference} seconds"
    end

    def supports_block_expectations?
      true
    end
  end

  RSpec::Matchers.define :exist do |*args|
    match do |actual|
      actual.exist?(*args)
    end

    failure_message do |obj|
      "expected #{obj.inspect} to exist"
    end

    failure_message_when_negated do |obj|
      "expected #{obj.inspect} to not exist"
    end
  end
end
