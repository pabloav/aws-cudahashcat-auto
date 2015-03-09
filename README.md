Automated GPU-accelerated hashcat cracking in the cloud
====

Purpose
----

Automate using GPU-accelerated hashcat in the cloud, for fast and inexpensive cracking

Background
----
One day, poking around on AWS, I saw someone had uploaded a CUDA Hashcat AMI, I started up an instance and did a quick test. I confirmed that the hashing speed corresponded with the benchmarks I found [here](http://hashcat.net/forum/thread-4143-post-23603.html).

The problem with GPU instances is that they're expensive. However on the spot market, they tend to be reasonably inexpensive (< $.07 / hr)

Initially I just set out to see how far I could get automating a spin up of a node to crack a password. Eventually I'd like to enable parallelism for even faster cracking.

Usage
----
#### Configuration
You need to look at the both the _run.sh_ and _launch-spot.sh_ scripts and you'll want to change the settings to match your AWS details and hash details

#### Performance
For nitty gritty details you can see the benchmark linked above, but to give a sense of the real-world performance:

- Runs all single Sha512 (unix crypt) hash against rockyou in ~21 minutes (~12000 H/s)

Compared to my MBP which takes a couple of hours to do the same (~900 H/s)

Overview
--------
There's two critical scripts involved.

- _launch-spot.sh_ - Launches a spot instance, at this point, this is where most of the settings you care about are

- _run.sh_ - This gets pulled down and run by the instance after it spins up, this is where most of the actual automation/cracking takes place

However, there's some other components at play:

EC2

 - We start a spot instance request
 - We associate the runtime parameters with the _spot instance request_ via Tags
 - If/when the instance is launched successfully, it will need to reference these tags

S3

 - We store the results of cracked passwords in an s3 bucket (/incoming/)
 - We also store a copy of rockyou.txt and pull it down from S3 in launch-spot.sh (/assets/) [optional, but you'll want to look at run.sh]
 - We enable versioning on the bucket, so that overwrites (unlikely) are preserved [optional]
 - We enable a lifecycle policy on the bucket, so objects are automatically removed from /incoming/ after 2 days [optional]

IAM

 - We create an IAM policy for the hashcat instances. They grant the following 4 permissions:
     - Describe EC2 Instances (to find the _spot instance request_ id)
     - Get tags (to retrieve the transient data from the _spot instance request_ tags)
     - PutObject (on the /incoming/ folder of the S3 bucket)
     - GetObject (on the /assets/ folder of the S3 bucket)

AWS CLI
 - We use the AWS CLI on the instnace to access the various AWS components

To Do
----
* Automating parallelization
* Bake AWS CLI into the AMI
* Bake rockyou.txt into the AMI (?)
* Provide some scripts to configure the IAM policy and S3 bucket
* Maybe move more of the hardcoded configuration from run.sh to _spot instance request_ tags (e.g., s3bucket, s3folder)

Credits
----
- https://gist.github.com/jareware/d7a817a08e9eae51a7ea
- http://stackoverflow.com/questions/3883315/query-ec2-tags-from-within-instance
