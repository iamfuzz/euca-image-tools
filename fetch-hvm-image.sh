#!/bin/sh

INSTANCE_SIZE="m3.xlarge"
AVAILABILITY_ZONE="us-east-1c"
AMI=$1
KEY=$2

if [ "$AMI" = "" ]; then
  echo "Missing AMI ID"
  echo "Usage: $0 ami-id key-name [scratch-ami-id]"
  exit 1
fi

if [ "$KEY" = "" ]; then
  echo "Missing key name"
  echo "Usage: $0 ami-id key-name [scratch-ami-id]"
  exit 1
fi

if [ "$4" != "" ]; then
  echo "Too many arguments"
  echo "Usage: $0 ami-id key-name [scratch-ami-id]"
  exit 1
fi

#Check to see if the users' ssh key exists
if [ ! -e ~/$KEY.priv ]; then
  Error: Unable to find key. Please ensure your ssh key is located at ~/$KEY.priv
  exit 1
fi

#TODO#
#Add command to verify it is an HVM image

#Launch the instance and when it enters the running state, stop it to snapshot its volume
echo "Launching HVM image on EC2..."
OUTPUT=`euca-run-instances -t $INSTANCE_SIZE -z $AVAILABILITY_ZONE $AMI`

INSTANCE=`echo $OUTPUT | sed -e 's/.*INSTANCE\s//' -e 's/\s.*$//'`
echo $INSTANCE

echo "Waiting for instance to enter 'running' state..."
while [ `euca-describe-instances $INSTANCE|tail -n1| awk '{print $6}'` != "running" ]; do
  sleep 5
done

echo "Stopping instance..."
euca-stop-instances $INSTANCE

#Create a snapshot of the HVM image volume, and then create our own volume from that
echo "Creating snapshot of HVM volume - this could take a while..."
VOLUME1=`euca-describe-volumes | grep $INSTANCE | awk '{print $2}'`
SNAPSHOT=`euca-create-snapshot $VOLUME1 |awk '{print $2}'`
echo $VOLUME1
echo $SNAPSHOT
#Wait for snapshot to finish
while [ `euca-describe-snapshots |grep $SNAPSHOT|head -n1|awk '{print $4}'` != "completed" ]; do
  sleep 5
done

#Get volume size
VOLUME_SIZE=`euca-describe-volumes $VOLUME1 |head -n1 |awk '{print $3}'`
echo $VOLUME_SIZE

#echo "Creating a volume from the HVM snapshot..."
VOLUME2=`euca-create-volume --snapshot $SNAPSHOT -z $AVAILABILITY_ZONE| awk '{print $2}'`
echo $VOLUME2

#Wait for volume creation to finish
while [ `euca-describe-volumes $VOLUME2 |tail -n1|awk '{print $6}'` != "available" ]; do
  sleep 5
done

#Start our 'scratch' instance and make sure it comes up
echo "Starting a 'scratch' instance to attach the newly created volume to..."
SCRATCH_AMI=""
if [ "$3" != "" ]; then
  SCRATCH_AMI=$3
else
  SCRATCH_AMI=`euca-describe-images |grep instance-store |head -n1 |awk '{print $2}'`
fi

if [ "SCRATCH_AMI" = "" ]; then
  echo "You must have a registered instance-store image in order to proceed"
  exit 1
fi

OUTPUT=`euca-run-instances -z $AVAILABILITY_ZONE $SCRATCH_AMI -k $KEY`

SCRATCH_INSTANCE=`echo $OUTPUT | sed -e 's/.*INSTANCE\s//' -e 's/\s.*$//'`
echo $SCRATCH_INSTANCE

echo "Waiting for scratch instance to enter 'running' state..."
while [ `euca-describe-instances $SCRATCH_INSTANCE|tail -n1|awk '{print $6}'` != "running" ]; do
  sleep 5
done
#wait an additional amount of time to ensure networking has come up
#TODO: wait till ping responds or something similar
sleep 20

#Get IP of scratch instance
SCRATCH_IP=`euca-describe-instances $SCRATCH_INSTANCE |tail -n1 |awk '{print $4}'`
echo $SCRATCH_IP

#Attach new volume to 'scratch' instance
echo "Attaching new volume to 'scratch' instance..."
euca-attach-volume -i $SCRATCH_INSTANCE $VOLUME2 -d /dev/sdf
#Wait for the volume to attach
while [ `euca-describe-volumes $VOLUME2 |tail -n1|awk '{print $5}'` != "attached" ]; do
  sleep 5
done
sleep 5

#Fetch image
NEW_IMAGE_NAME=`mktemp`

echo ssh -i ~/$KEY.priv root@$SCRATCH_IP "gzip - < /dev/xvdf" | zcat > $NEW_IMAGE_NAME;
ssh -i ~/$KEY.priv root@$SCRATCH_IP "gzip - < /dev/xvdf" | zcat > $NEW_IMAGE_NAME;
   
#Success! (we hope)
echo "Your new image is located at: $NEW_IMAGE_NAME"

#Terminate scratch instance
euca-terminate-instances $SCRATCH_INSTANCE
