// SPDX-License-Identifier: MIT
pragma solidity >=0.4.16 <0.9.0;

contract SimpleStorage {
    uint storedData;

    function set(uint x) public {
        storedData = x;
    }

    function get() public view returns (uint) {
        return storedData;
    }

    struct Person {
        uint age;
        string name;
    }

    Person public peter = Person({
        age : 20,
        name : "Peter"
    });

    // Add a person in a list
    Person[] public listOfPersons;

    // Mapping
    mapping(string => uint) public nameToAge;

    function addPerson(uint age, string memory name) public {
        listOfPersons.push(Person(age,name));
        nameToAge[name] = age;
    }
}