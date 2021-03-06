class Enrollment < ActiveRecord::Base
  FINANCE_FEE      = 1000
  PAYMENT_COUNT    = 6
  BASE_PRICE       = 7500

  has_many   :payments, dependent: :destroy
  has_one    :student


  validates :email,       presence: true,
                          uniqueness: { case_sensitive: false, message: "has already been registered"},
                          format: { with: /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z/i }

  validates :name,        presence: true

  default_scope -> {
    oldest
  }

  scope :billable, -> {
    # it is price - 10 because I am not charging cents and so therefore
    # it will otherwise bill one too many times (as the sum of 5 payments
    # will still be less than the price of the produce)
    joins("LEFT JOIN payments ON payments.enrollment_id = enrollments.id").
      group("enrollments.id").
      having("SUM(payments.amount) < (enrollments.price - 10) AND
              MAX(payments.created_at) < current_date - interval '1' month AND
              paused <> true")
  }

  scope :active, -> {
    where("stripe_id IS NOT NULL AND
           refunded_at IS NULL AND
           rejected_at IS NULL")
  }

  scope :interviewing, -> {
    where("interview_invitation_sent_at >= ? AND
           stripe_id IS NULL", 2.weeks.ago)
  }

  scope :pending, -> {
    where("stripe_id IS NULL AND
           refunded_at IS NULL AND
           interview_invitation_sent_at IS NULL AND
           rejected_at IS NULL")
  }

  scope :refunded, -> {
    where("refunded_at IS NOT NULL")
  }

  scope :rejected, -> {
    where("rejected_at IS NOT NULL")
  }

  scope :oldest, -> {
    order(created_at: :asc)
  }

  before_create :record_pricing

  def self.charge_billable_accounts
    billable.map do |e|
      e.payments.create(amount: e.next_payment_amount).tap do |p|
        p.charge
      end
    end
  end

  def self.payment_price
    financed_price / PAYMENT_COUNT
  end

  def self.financed_price
    BASE_PRICE + FINANCE_FEE
  end

  def invite_to_interview!
    InterviewInvitationMailer.notify(self).deliver_now
    update_attributes(interview_invitation_sent_at: DateTime.now)
  end

  def first_name
    name.split(" ").first
  end

  def interview_invitation_sent_on
    interview_invitation_sent_at &&
      interview_invitation_sent_at.to_date
  end

  def enrolled_on
    return nil if enrolled_at.nil?
    enrolled_at.to_date
  end

  def enrolled_at
    return nil if payments.none? ||
                  payments.oldest.first.nil?
    payments.oldest.first.created_at
  end

  def applied_on
    created_at.to_date
  end

  def rejected_on
    rejected_at.to_date
  end

  def refunded_on
    refunded_at.to_date
  end

  def refunded?
    refunded_at.present?
  end

  def pay_option=(val)
    write_attribute(:financed, val == "payments" )
  end

  def pay_option
    financed? ? "payments" : "prepay"
  end

  def price
    read_attribute(:price) || BASE_PRICE
  end

  def adjusted_price
    financed? ? price + FINANCE_FEE : price
  end

  def next_payment_amount
    layaway ? price / 2 : price
  end

  def initial_payment_made?
    payments.select(&:persisted?).any?
  end

  def record_pricing
    write_attribute(:price, adjusted_price)
  end

end

