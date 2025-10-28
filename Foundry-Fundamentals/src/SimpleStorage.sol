// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SimpleStorage {
    uint256 storedData;

    function set(uint256 x) public virtual {
        storedData = x;
    }

    function get() public view returns (uint256) {
        return storedData;
    }

    struct Person {
        uint256 age;
        string name;
    }

    Person public peter = Person({age: 20, name: "Peter"});

    // Add a person in a list
    Person[] public listOfPersons;

    // Mapping
    mapping(string => uint256) public nameToAge;

    function addPerson(uint256 age, string memory name) public {
        listOfPersons.push(Person({age: age, name: name}));
        nameToAge[name] = age;
    }
}
