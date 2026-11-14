# /model -- Model Builder

You are creating or modifying a model for Aluni. The request is: $ARGUMENTS

## Before writing code:

1. Read `docs/DATA_MODEL.md` (tables and conventions)
2. Read the most similar existing model: `app/models/passkey.rb`, `app/models/user.rb`, `app/models/notification_delivery.rb`
3. Read `db/schema.rb` for the current state
4. Read `spec/factories/` for the existing factories

## Migrations

ALWAYS use the generator:
```bash
mise exec -- bin/rails generate model Thing user:references name:string status:integer
mise exec -- bin/rails generate migration AddPositionToThings position:integer
mise exec -- bin/rails db:migrate
```

Column conventions: `null: false` for required columns; `default:` where sensible; integer enums `t.integer :status, null: false, default: 0`; flexible data `t.jsonb :metadata, null: false, default: {}`; money `t.integer :amount_minor` or `t.decimal :amount, precision: 10, scale: 2`; `t.references :user, null: false, foreign_key: true`; encrypted fields are plain string/text columns (`encrypts` in the model).

Indexes: references get one automatically; add indexes for `WHERE`/`ORDER BY` columns; composite for common pairs (`[:user_id, :status]`); `unique: true` for natural keys; partial (`where: "... IS NOT NULL"`) for nullable uniques.

## Model structure (this order)

```ruby
class Thing < ApplicationRecord
  # 1. Associations
  belongs_to :user
  has_many :items, dependent: :destroy
  has_one_attached :image

  # 2. Enums (integer-backed, gaps for future values)
  enum :status, { draft: 0, active: 10, archived: 20 }

  # 3. Encrypted fields
  encrypts :sensitive_data

  # 4. Scopes
  scope :active, -> { where(status: :active) }
  scope :recent, -> { order(created_at: :desc) }

  # 5. Validations
  validates :name, presence: true, length: { maximum: 100 }

  # 6. Callbacks
  before_validation :assign_reference, on: :create

  # 7. Public methods: can_x? guards and x! transitions
  def can_activate? = draft?

  def activate!
    raise ArgumentError, "cannot activate from #{status}" unless can_activate?

    update!(status: :active)
  end

  private

  # 8. Private methods
  def assign_reference
    self.reference ||= SecureRandom.alphanumeric(8).upcase
  end
end
```

Broadcasts (`after_update_commit -> { broadcast_replace_to(...) }`) only where a live screen exists. No business logic in models; services own it.

## Factory template (`spec/factories/<plural>.rb`)

```ruby
FactoryBot.define do
  factory :thing do
    user
    name { Faker::Lorem.word.capitalize }
    status { :active }

    trait :archived do
      status { :archived }
    end
  end
end
```

## Model spec template (`spec/models/<name>_spec.rb`)

```ruby
require "rails_helper"

RSpec.describe Thing, type: :model do
  it { is_expected.to belong_to(:user) }
  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to define_enum_for(:status).with_values(draft: 0, active: 10, archived: 20) }

  it "activates from draft only" do
    thing = create(:thing, status: :draft)
    thing.activate!
    expect(thing.reload).to be_active
    expect { thing.activate! }.to raise_error(ArgumentError)
  end
end
```

## i18n for models

Add to `config/locales/en/en.activerecord.yml` and `config/locales/es/es.activerecord.yml` (same keys): `activerecord.models.thing` (`one`/`other`) and `activerecord.attributes.thing.<field>`. The parity spec fails if one locale is missing a key.
