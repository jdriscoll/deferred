# Deferred

## Description

Thread safe Deferred class for Swift 2. Based on [https://github.com/bignerdranch/Deferred](https://github.com/bignerdranch/Deferred).

## Usage

    // Create a new deferred that stores an Int
    let i = Deferred<Int>()

    // When filled, convert it to a string and then print it
    i.map {
        return "The number is \($0)"
    }.then {
        print($0)
    }

    i.fill(42) // "The number is 42"
