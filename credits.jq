# JQ Filter File

# Calculate total credits for the circleci build. Uses `build_time_millis` and calculates credits depending on class.

# Get all the pieces needed, use of vars should not affect actual body

# define factors to calculate by, depending on class
{"small":5,"medium":10,"medium+":15,"large":20} as $classes |

# create a new array
[
# using the elements of the original as basis
.[] |
# and appending 2 new fields to each element: `build_time_minutes` and `credits`
. + { "build_time_minutes": (.build_time_millis / 1000 / 60), "credits": ($classes[.picard.resource_class.class] * (.build_time_millis / 1000 / 60) | floor) }
# and close the array
]

# use for active builds that dont yet gave stop/run time 
#((now - ($start | split(".")[] +"Z" | fromdate)) / 60) as $build_time |
