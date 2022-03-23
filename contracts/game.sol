//SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

//import library
import "./libraries/gameLib.sol";

//import interfaces
import "./interfaces/IMinter.sol";
import "./interfaces/IStats.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

contract game {

    //define a struct for a games vars
    //this should include: 
    //players addresses
    //pot = entry fee * 2
    //player 1 tokens
    //player 1 energy
    //player 2 tokens
    //player 2 energy
    //bool openForPlayer2
    //bool gameActive
    //anything else?
    

    //define a mapping to store gameId => gameVars



    //store the addresses of:
    //the admin & community wallet 
    //the minter, energy & stats contracts 


    //constructor

    //function here for building game vars



    //player 1 initiates a open room game & sets the entry price
    //the player must submit the tokens they would like to enter
    //each card must be checked that the player entering the cards, owns those cards
    //the player must deposit the amount the player would like to wager
    //create the game vars using the build vars function



    //player 2 joins a room that has a set price
    //check that the gameID exists & is open to be joined
    //the player must submit the tokens they would like to enter
    //each card must be checked that the player entering the cards, owns those cards
    //the player must deposit the amount the player would like to wager
    //edit the gamevars    


    //player 1 can end the game with no consequences if there is no player 2
    //possible reentrancy vulnerability, add reentrancy guard & finish all state changes before transferring the funds back to the caller


    //player 1 & 2 take turns here
    //the player must be able to switch a energy card from one played card to another if the element type is the same
    //the player must be able to choose a card to place into the main fight section or on the bench
    //the player must be able to choose what attack they will use
    //the player must be able to choose if they wants to skip an attack



    //surrender function to allow games to be quit mid game aslong as 1 side wants to quit, the opponent is by default the winner


    //split funds between winner & community wallet


    //vrf request for random number
    //decides what card from the winners deck will be upgraded & upgrades it

    



}