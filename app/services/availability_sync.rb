class AvailabilitySync
  def initialize(client: CalendlyClient.new)
    @client = client
  end

  # Syncs availabilities for a provider based on the Calendly feed.
  # Converts day_of_week + time format to specific datetime ranges for the next 4 weeks
  def call(provider_id:)
    provider = Provider.find(provider_id)
    slots = client.fetch_slots(provider_id)

    return if slots.empty?

    # Generate availability windows for the next 4 weeks
    start_date = Date.current
    end_date = start_date + 4.weeks

    slots.each do |slot|
      generate_availability_windows(provider, slot, start_date, end_date)
    end

    provider.availabilities.count
  end

  private

  attr_reader :client

  def generate_availability_windows(provider, slot, start_date, end_date)
    # Map day names to numbers (0 = Sunday, 1 = Monday, etc.)
    day_mapping = {
      "sunday" => 0, "monday" => 1, "tuesday" => 2, "wednesday" => 3,
      "thursday" => 4, "friday" => 5, "saturday" => 6
    }

    starts_day_num = day_mapping[slot["starts_at"]["day_of_week"].downcase]
    ends_day_num = day_mapping[slot["ends_at"]["day_of_week"].downcase]

    start_time = Time.parse(slot["starts_at"]["time"])
    end_time = Time.parse(slot["ends_at"]["time"])

    # Find all dates in the range that match the start day
    current_date = start_date
    while current_date <= end_date
      if current_date.wday == starts_day_num
        # Calculate the actual datetime for this occurrence
        slot_start = current_date.in_time_zone.change(
          hour: start_time.hour,
          min: start_time.min,
          sec: 0
        )

        # Handle cross-day appointments (e.g., Monday 23:30 to Tuesday 00:15)
        slot_end_date = current_date
        if ends_day_num != starts_day_num
          # If end day is the next day, add 1 day
          if (ends_day_num - starts_day_num) % 7 == 1
            slot_end_date = current_date + 1.day
          end
        end

        slot_end = slot_end_date.in_time_zone.change(
          hour: end_time.hour,
          min: end_time.min,
          sec: 0
        )

        # Create or update the availability record
        availability_attrs = {
          provider: provider,
          external_id: "#{slot['id']}-#{current_date.strftime('%Y-%m-%d')}",
          starts_at: slot_start,
          ends_at: slot_end,
          source: slot["source"]
        }

        Availability.find_or_create_by!(external_id: availability_attrs[:external_id]) do |avail|
          avail.assign_attributes(availability_attrs)
        end
      end

      current_date += 1.day
    end
  end
end
