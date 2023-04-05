# RACER record maker

## What does it do?
This script generates a webform to be used by library staff to create a record in Alma for circulating RACER items.
* Staff fill in a RACER number and the barcode that will be used to circulate the item in Alma.
* When submitted, the form calls a script which validates the form input.
* If valid, the script creates a bibliographic record, a holding record and an item record.
* If invalid, the form displays an error to the staff user.

## What do I need to do to use this?
There are several things that will need to be configured:
* Security is not built-in, so you will want to restrict access to the script. (In our case, we're using simple .htaccess and .htpasswds )
* API keys are managed in a local Perl module in libperl/AlmaAPI.pm. I'd recommend keeping this module outside of the public_html folder.
* Generate an API key at https://developers.exlibrisgroup.com/ with 'Bibs - Production Read/write' permission and use this as the key value for $QuickTitle_api_key in AlmaAPI.pm
* Add your Alma institution code to AlmaAPI.pm (e.g., ours is 01OCUL_TU)
* Enter the location of your local Perl library path(s) in racer-records.pl
* Enter the library and location you want to use for RACER items.

## Anything else?
* Other than our library logo, I haven't removed much of our local styling for the HTML templates.
