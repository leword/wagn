Feature: Set settings
  In order to control settings in an efficient way
  As a Wagneer
  I want to be able to control settings for sets of cards
  
  Background:
    Given I log in as Joe User
    And I create card "*all+*add help" with content "say something spicy"

  Scenario: default setting and plus card override
    Given I create Phrase card "color+*right+*add help" with content "If colorblind, leave blank"
    When I go to new card "Test"
    Then I should see "spicy"
    When I go to new card "Test+color"      
    Then I should see "colorblind"
  
  Scenario: rform Set
    Given I create Phrase card "cereal+*right+*add help" with content "I go poopoo for poco puffs"
    When I go to new card named "Test+cereal"
    Then I should see "poopoo"

  Scenario: Solo Set
    Given I create Pointer card "cereal+*self+*layout" with content "[[cereal layout]]" 
    And I create card "cereal layout" with content "My very own header"
    When I go to card "cereal"
    Then I should see "My very own"


  
