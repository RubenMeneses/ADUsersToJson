# ADUsersToJson
Extracts AD User Info to Json
Each line in thte json file represents a user record.
This formwat of this file can be used with FileBeats to get data into elasticsearch.
An output json file will be created enery time the script runs.
The script will delete old files, a variable $MaxDaysToKeep is used to define when the files will be deleted.
Other user properties can be added by adding new lines in this format at the $null=$PropList.Add("<Property name>")
Remove any properties that are not required.
