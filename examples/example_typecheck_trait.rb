ENV['RUBY_INTERFACE_TYPECHECK'] = "1"
require 'interface'

# Drivable specifies an interface
# The arity of the stop method should be 1
# That arity of the other methods will not be validated
Drivable = interface do
  public_visible(:turn_left, :turn_right, :start, { stop: 1 })
end

# Car is an implementation of Drivable
class Car
  def turn_left; :left; end
  def turn_right; :right; end
  def start; end
  def stop(urgency); end

  implements Drivable
end

# Does not implement Drivable
class BadCar
  def turn_left; :error; end
end

# Turnable interface for things that can turn
Turnable = interface do
  public_visible :turn_left, :turn_right
end

# Driver interface for things that can be driven
# Interfaces are composable
Driver = interface do
  include Turnable
  public_visible :start, :stop
end

# RaceDriver implements Driver
# It can be used as a trait which is mixed into other modules
# It can also be instantiated into an engine or driver object
module RaceDriver
  def turn_left; car.turn_left end
  def turn_right; car.turn_right end
  def start; car.start end
  def stop; car.stop end
  implements Driver

  extend Interface::Trait
  # Requires that the including module satisfy the interface given below
  requires_interface(interface { private_visible :car })

  # To create an engine object from this trait, define
  # an engine constructor using `initiator`.
  # This creates a constructor method called `create`
  # The create method accepts an object which must satisfy
  # the `Drivable` interface. This object is available as 'car'
  # in the trait object.
  instantiator :create, :car, Drivable
end

class Person
  def initialize(age:, car:)
    # Check that `car` implements Drivable
    check_interface { { Drivable => car } }
    @age = age
    @car = car
  end

  private

  attr_reader :car
end

# 'Mixin' the RaceDriver trait
# This will perform the `requires_interface` check
Racer = Person.include(RaceDriver)

# Instantiate a trait object which wraps the object that is passed
# The interface specified in the `instantiator` call is checked
# here
racer = RaceDriver.create(Car.new) # Instantiated trait object

puts Racer.new(age: 20, car: Car.new).turn_left
puts racer.turn_left
