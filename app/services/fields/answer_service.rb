# frozen_string_literal: true

module Fields
  # Records one thing the person did with a datum of the farm or a field:
  # confirm an inferred value, or give a value (an answer, or a correction of
  # an inferred one). Takes the farm data and returns the updated copy; the
  # caller decides where it is kept (Fields::Draft today).
  class AnswerService < ApplicationService
    MAX_TEXT = 200

    def initialize(data:, subject:, datum:, value: nil, confirm: false, profile: Profile.current)
      @data = data.deep_dup
      @subject = subject.to_s
      @datum_key = datum.to_s
      @value = value
      @confirm = confirm
      @profile = profile
    end

    def call
      target = step find_target
      datum = step find_datum(target[:level])

      if @confirm
        target[:body]["confirmed"] = (Array(target[:body]["confirmed"]) | [ datum.key ])
        target[:body]["answers"]&.delete(datum.key)
      else
        target[:body]["answers"] = target[:body]["answers"].to_h.merge(datum.key => step(clean(datum)))
      end
      Success(@data)
    end

    private

    def find_target
      return Success(level: "farm", body: @data) if @subject == "farm"

      body = @data.dig("fields", @subject)
      body ? Success(level: "field", body: body) : Failure(code: :not_found)
    end

    def find_datum(level)
      datum = @profile.data(level).find { |d| d.key == @datum_key }
      datum ? Success(datum) : Failure(code: :not_found)
    end

    # Options must be the datum's own; area a positive number; history a crop
    # per year; anything else short text.
    def clean(datum)
      if datum.key == "crop_history"
        crops = @profile.fetch("current_crop").options
        history = @value.to_h.to_h { |year, crop| [ year.to_s, crop.to_s ] }.select { |year, crop| year.match?(/\A\d{4}\z/) && crops.include?(crop) }
        history.any? ? Success(history) : Failure(code: :invalid)
      elsif datum.options.any?
        values = Array(@value).map(&:to_s).compact_blank
        return Failure(code: :invalid) if values.empty? || (values - datum.options).any?

        Success(datum.multiple ? values : values.first)
      elsif datum.number
        number = Float(@value, exception: false)
        number&.positive? && number < 1_000_000 ? Success(number.round(2)) : Failure(code: :invalid)
      else
        text = @value.to_s.strip
        text.present? && text.length <= MAX_TEXT ? Success(text) : Failure(code: :invalid)
      end
    end
  end
end
