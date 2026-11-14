# Core scenarios for the BodyLogs I/O Ledger (NASA Space Apps 2026).
# Rule for every scenario: no value is typed by a human; every record keeps its sources.

Feature: Body I/O ledger with zero manual input
  As a crew member on a long-duration mission
  I want everything my body takes in and puts out to be logged automatically
  So that the crew and the flight surgeon can assess my health and act early

  Background:
    Given the habitat has a galley zone and a toilet zone
    And every crew member carries a personal device that identifies them
    And every crew member has a personal logging journal

  # ---------- Intake ----------

  Scenario: Meal from a packed food item with an NFC tag
    Given packed food "Beef stew" with a registered NFC tag on it
    And the packed food lays in a box that is continuously monitored by weights
    And a person "John Doe" is wearing all needed sensors
    And "John Doe" is in the galley zone
    When "John Doe" grabs one pack of "Beef stew"
    And the box weight drops by the weight of one pack
    And the intake sensor is triggered by a swallow move
    Then a "food_intake" record is written to "John Doe"'s logging journal
    And the record contains the item "Beef stew" and the eaten mass in grams
    And the record contains the start and end timestamps of the meal
    And the record lists its sources "nfc", "scale", "swallow" and "zone"
    And the record status is "confirmed"

  Scenario: Water from a personal cup
    Given a personal cup with "John Doe"'s registered NFC tag on it
    And the cup stands on a continuously monitored scale
    And "John Doe" is wearing all needed sensors
    When "John Doe" lifts the cup and drinks
    And the cup weight drops by 250 g within 3 minutes
    And the intake sensor is triggered by swallow moves
    Then a "water_intake" record of 250 ml is written to "John Doe"'s logging journal
    And timestamp recorded
    And "John Doe"'s daily fluid intake total is updated

  Scenario: Low daily fluid intake triggers an action
    Given "Jane Roe" has a planned fluid intake of 2.8 L per day
    And "Jane Roe"'s logging journal shows 900 ml of fluids since wake-up
    When the afternoon check runs at 15:00
    Then an action card "Drink 500 ml in the next 2 hours" is shown to "Jane Roe"
    And the action card is recorded in "Jane Roe"'s logging journal with a timestamp
    And the action card is closed when the next "water_intake" record for "Jane Roe" arrives

  # ---------- Outtake ----------

  Scenario: Urination is logged with volume and color
    Given "John Doe" is identified in the toilet zone
    And the toilet has a flow sensor and a color sensor
    When "John Doe" urinates
    And the flow sensor measures 320 ml over 25 seconds
    And the color sensor reads "pale yellow"
    Then a "toilet_number_1" record is written to "John Doe"'s logging journal
    And the record contains volume, flow rate, color and timestamp
    And the record lists its sources "zone", "flow" and "color"
    And the record status is "confirmed"

  Scenario: Defecation is logged and transit time is calculated
    Given "Jane Roe" is identified in the toilet zone
    And the toilet seat pressure sensor detects that someone sits
    And "Jane Roe"'s logging journal has a "food_intake" record with a marker meal 26 hours ago
    When a stool event is detected with mass 150 g and Bristol type 4
    Then a "toilet_number_2" record is written to "Jane Roe"'s logging journal
    And timestamp recorded
    And the gut transit time of 26 hours is calculated from the marker meal

  Scenario: Low urine output raises a renal stone risk alert
    Given "Alex Poe"'s logging journal shows 1.4 L of urine over the last 24 hours
    And the threshold is 2 L of urine per day according to NASA HRP renal stone risk evidence
    When the 24-hour window closes
    Then an alert "Urine below 2 L/day: renal stone risk" is raised for "Alex Poe"
    And an action card "Drink +600 ml spread over the next 6 hours" is shown to "Alex Poe"
    And the urine trend is visible in the flight surgeon view

  # ---------- Anomalies ----------

  Scenario: Location conflicts with an outtake event
    Given "Sam Moe"'s personal device places "Sam Moe" in the lab zone
    When the toilet sensors report an outtake event
    And the outtake event is attributed to "Sam Moe" by an NFC tap
    Then the outtake record is stored unchanged
    And the record status is "conflict"
    And the record is added to the read-and-validate queue
    And nobody can edit the record values

  Scenario: Eating in an unusual place
    Given "John Doe"'s personal device places "John Doe" at the workstation zone
    When a "food_intake" event for "John Doe" arrives from the workstation zone
    Then the record is written to "John Doe"'s logging journal with status "confirmed"
    And the record is flagged "eating outside the galley"
    And an overload signal is raised for "John Doe" if this is the third such record within 2 days
