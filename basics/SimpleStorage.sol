// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

contract SimpleStorage {
    uint storedData;

    function set(uint256 x) public virtual {
        storedData = x;
    }

    function get() public view returns (uint256) {
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