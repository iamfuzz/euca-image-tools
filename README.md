euca-image-tools
================
Pre-requisites:

* An AWS account
* Obtaining the AMI ID of the HVM (Hardware Virtual Machine) image you'd like to import
* An instance store AMI in your account to be used as a scratch instance with root access (some Ubuntu images may not work as they use user ubuntu instead)
* Enough disk space in the TEMPDIR on your local machine to store the image
* An ssh key setup on AWS and downloaded to your home directory as <key-name>.priv

Once you have downloaded the script, make sure you have your AWS secret key and access key exported in your shell environment, and then run it as follows:

./fetch-hvm-image ami-XXXXXXXX key-name [ami-XXXXXXXX]

The first AMI is the HVM AMI and is required.  The second AMI argument is optional and if left unspecified, the script will use the first instance-store AMI in your account that it finds.

If the script finishes successfully, it will display the image location in your TEMPDIR.  From there you can import it manually into your Eucalyptus setup or use the new, unofficial version of eustore mentioned in my previous blog post to do it for you.

Please note that many images will require modifications before importation.  For instance, the official SuSe images have startup scripts in them specific to AWS that can cause boot problems in Euca an must be disabled.
