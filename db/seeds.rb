# Seed data for development and testing

# Create providers
provider1 = Provider.find_or_create_by!(email: "dr.smith@example.com") do |p|
  p.name = "Dr. Sarah Smith"
end

provider2 = Provider.find_or_create_by!(email: "dr.jones@example.com") do |p|
  p.name = "Dr. Michael Jones"
end

provider3 = Provider.find_or_create_by!(email: "dr.brown@example.com") do |p|
  p.name = "Dr. Emily Brown"
end

# Create clients
client1 = Client.find_or_create_by!(email: "john.doe@example.com") do |c|
  c.name = "John Doe"
  c.phone = "+1-555-0123"
end

client2 = Client.find_or_create_by!(email: "jane.smith@example.com") do |c|
  c.name = "Jane Smith"
  c.phone = "+1-555-0124"
end

client3 = Client.find_or_create_by!(email: "bob.wilson@example.com") do |c|
  c.name = "Bob Wilson"
  c.phone = "+1-555-0125"
end

puts "Created #{Provider.count} providers and #{Client.count} clients"
puts "Providers: #{Provider.pluck(:name).join(', ')}"
puts "Clients: #{Client.pluck(:name).join(', ')}"
