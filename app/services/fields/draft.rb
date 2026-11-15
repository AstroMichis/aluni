# frozen_string_literal: true

module Fields
  # Where the preview keeps the person's farm until farms are stored: the
  # session (a signed cookie), nothing in the database. Without a draft the
  # sample farm shows. Swap this class for the farm tables and nothing else
  # changes: it hands out and takes back the data shape of Fields::Farm.
  class Draft
    KEY = :fields_draft

    def initialize(session)
      @session = session
    end

    def data = @session[KEY].presence || Farm.sample_data
    def farm = Farm.build(data)

    def save(data)
      @session[KEY] = data
    end

    def reset!
      @session.delete(KEY)
    end
  end
end
