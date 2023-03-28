#!/bin/bash
set -ex

# echo "This is the value specified for the input 'example_step_input': ${example_step_input}"

#
# --- Export Environment Variables for other Steps:
# You can export Environment Variables for other Steps with
#  envman, which is automatically installed by `bitrise setup`.
# A very simple example:
# envman add --key EXAMPLE_STEP_OUTPUT --value 'the value you want to share'
# Envman can handle piped inputs, which is useful if the text you want to
# share is complex and you don't want to deal with proper bash escaping:
#  cat file_with_complex_input | envman add --KEY EXAMPLE_STEP_OUTPUT
# You can find more usage examples on envman's GitHub page
#  at: https://github.com/bitrise-io/envman

#
# --- Exit codes:
# The exit code of your Step is very important. If you return
#  with a 0 exit code `bitrise` will register your Step as "successful".
# Any non zero exit code will be registered as "failed" by `bitrise`.

# This is step.sh file for iOS apps


download_file() {
	file_location=$1
	uri=$(echo $file_location | awk -F "?" '{print $1}')
	downloaded_file=$(basename $uri)
	curl $file_location --output $downloaded_file && echo $downloaded_file
}

download_array_elements() {
	file_list=""
	array=$@
	i=0
	for element in ${array[@]}
	do
		file=$(download_file $element)
		if [ $i -eq 0 ]; then
 		file_list=$file
 		else
 			file_list="${file_list},${file}"
 		fi
 		i=$((i+1))
	done
	echo $file_list
}

export X-Appdome-Client="Bitrise/1.0.0"
app_file=$(download_file $APP_LOCATION)

echo $app_file

certificate_output=../certificate.pdf
output=../Appdome_${app_file}

tm=""
if [[ -n $team_id ]]; then
	tm="--team_id ${team_id}"
fi

git clone https://github.com/Appdome/appdome-api-bash.git
cd appdome-api-bash

echo "iOS platform detected"
pf=$(echo $provisioning_profiles)
pf_list=$(download_array_elements $pf)

ef=$(echo $entitlements)
ef_list=$(download_array_elements $ef)
ls -al
en=""
if [[ -n $entitlements ]]; then
	en="--entitlements ${ef_list}"
fi

case $sign_method in
"Private-Signing")		echo "Private Signing"						
						./appdome_api.sh --api_key $APPDOME_API_KEY \
							--app ../$app_file \
							--fusion_set_id $fusion_set_id \
							$tm \
							--private_signing \
							--provisioning_profiles $pf_list \
							$en \
							--output $output \
							--certificate_output $certificate_output 
						;;
"Auto-Dev-Signing")		echo "Auto Dev Signing"
						./appdome_api.sh --api_key $APPDOME_API_KEY \
							--app ../$app_file \
							--fusion_set_id $fusion_set_id \
							$tm \
							--auto_dev_private_signing \
							--provisioning_profiles $pf_list \
							$en \
							--output $output \
							--certificate_output $certificate_output 
						;;
"On-Appdome")			echo "On Appdome Signing"
						keystore_file=$(download_file $BITRISEIO_CERT_URL)
						keystore_pass=$BITRISEIO_IOS_KEYSTORE_PASSWORD
						./appdome_api.sh --api_key $APPDOME_API_KEY \
							--app ../$app_file \
							--fusion_set_id $fusion_set_id \
							$tm \
							--sign_on_appdome \
							--keystore $keystore_file \
							--keystore_pass $keystore_pass \
							--provisioning_profiles $pf_list \
							$en \
							--output $output \
							--certificate_output $certificate_output 
						;;
esac

cd ..
rm -rf appdome-api-bash
ls -al
cp * $BITRISE_DEPLOY_DIR