# Exercise catalog seed data
# ~150 exercises across 13 muscle groups
# Idempotent: safe to run multiple times

exercises = {
  "Chest" => [
    "Bench Press", "Incline Bench Press", "Decline Bench Press",
    "Dumbbell Bench Press", "Incline Dumbbell Press", "Decline Dumbbell Press",
    "Dumbbell Fly", "Incline Dumbbell Fly", "Cable Fly",
    "Cable Crossover", "Pec Deck", "Push-Up",
    "Chest Dip", "Machine Chest Press", "Landmine Press"
  ],
  "Back" => [
    "Deadlift", "Barbell Row", "Dumbbell Row",
    "Pull-Up", "Chin-Up", "Lat Pulldown",
    "Seated Cable Row", "T-Bar Row", "Pendlay Row",
    "Face Pull", "Straight Arm Pulldown", "Machine Row",
    "Inverted Row", "Single Arm Cable Row", "Meadows Row"
  ],
  "Shoulders" => [
    "Overhead Press", "Dumbbell Shoulder Press", "Arnold Press",
    "Lateral Raise", "Front Raise", "Rear Delt Fly",
    "Cable Lateral Raise", "Machine Shoulder Press", "Upright Row",
    "Dumbbell Rear Delt Fly", "Cable Rear Delt Fly", "Bradford Press"
  ],
  "Quadriceps" => [
    "Barbell Squat", "Front Squat", "Leg Press",
    "Leg Extension", "Hack Squat", "Goblet Squat",
    "Bulgarian Split Squat", "Walking Lunge", "Sissy Squat",
    "Smith Machine Squat", "Pistol Squat", "Step-Up"
  ],
  "Hamstrings" => [
    "Romanian Deadlift", "Lying Leg Curl", "Seated Leg Curl",
    "Stiff Leg Deadlift", "Good Morning", "Nordic Hamstring Curl",
    "Single Leg Romanian Deadlift", "Glute Ham Raise", "Cable Pull-Through",
    "Sumo Deadlift", "Kettlebell Swing"
  ],
  "Glutes" => [
    "Hip Thrust", "Barbell Hip Thrust", "Glute Bridge",
    "Cable Kickback", "Donkey Kick", "Fire Hydrant",
    "Sumo Squat", "Frog Pump", "Single Leg Hip Thrust",
    "Cable Pull-Through", "Smith Machine Hip Thrust"
  ],
  "Biceps" => [
    "Barbell Curl", "Dumbbell Curl", "Hammer Curl",
    "Preacher Curl", "Concentration Curl", "Cable Curl",
    "Incline Dumbbell Curl", "EZ Bar Curl", "Spider Curl",
    "Reverse Curl", "Bayesian Curl", "Drag Curl"
  ],
  "Triceps" => [
    "Tricep Pushdown", "Skull Crusher", "Close Grip Bench Press",
    "Overhead Tricep Extension", "Dumbbell Kickback", "Cable Overhead Extension",
    "Diamond Push-Up", "Dip", "JM Press",
    "French Press", "Single Arm Pushdown", "Rope Pushdown"
  ],
  "Core" => [
    "Plank", "Crunch", "Russian Twist",
    "Hanging Leg Raise", "Ab Wheel Rollout", "Cable Crunch",
    "Bicycle Crunch", "Dead Bug", "Pallof Press",
    "Woodchop", "Decline Sit-Up", "Dragon Flag"
  ],
  "Calves" => [
    "Standing Calf Raise", "Seated Calf Raise", "Donkey Calf Raise",
    "Single Leg Calf Raise", "Leg Press Calf Raise", "Smith Machine Calf Raise",
    "Tibialis Raise"
  ],
  "Forearms" => [
    "Wrist Curl", "Reverse Wrist Curl", "Farmer's Walk",
    "Dead Hang", "Plate Pinch", "Wrist Roller",
    "Gripper"
  ],
  "Traps" => [
    "Barbell Shrug", "Dumbbell Shrug", "Rack Pull",
    "Face Pull", "Farmer's Walk", "Cable Shrug",
    "Behind the Back Shrug"
  ],
  "Full Body" => [
    "Clean and Press", "Thruster", "Burpee",
    "Turkish Get-Up", "Man Maker", "Clean and Jerk",
    "Snatch", "Battle Ropes"
  ]
}

total = 0
exercises.each do |muscle_group, names|
  names.each do |name|
    Exercise.find_or_create_by!(name: name, muscle_group: muscle_group, is_custom: false)
    total += 1
  end
end

puts "Seeded #{total} exercises across #{exercises.keys.count} muscle groups"
