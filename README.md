# VarFish Docker Compose Configuration

This repository contains the [Docker Compose](https://docs.docker.com/compose/) configuration for the [VarFish Server](https://github.com/bihealth/varfish-server).

## Development Setup

This section describes the steps needed for a development setup.

### Prerequites

You will need to fetch some of this from our S3 server.
We recommend the `s5cmd` tool as it is easy to install, use, and fast.
You can download it from [github.com/peak/s5cmd/releases](https://github.com/peak/s5cmd/releases).
For example:

```bash session
$ wget -O /tmp/s5cmd_2.1.0_Linux-64bit.tar.gz \
    https://github.com/peak/s5cmd/releases/download/v2.1.0/s5cmd_2.1.0_Linux-64bit.tar.gz
$ tar -C /tmp -xf /tmp/s5cmd_2.1.0_Linux-64bit.tar.gz
$ sudo cp /tmp/s5cmd /usr/local/bin/
```

You will need to install Docker Compose.
Note that the "modern" way is to do this by using the docker compose plugin.
Instructions can be found [here on the Docker.com website](https://docs.docker.com/compose/install/linux/#install-using-the-repository).

### Checkout and Configure

First, clone the repository:

```bash session
$ git clone git@github.com:bihealth/varfish-docker-compose-ng.git
```

From here on, the commands should be executed from within this repository (`cd varfish-docker-compose-ng`).

We will use the directory `.dev` within the checkout for storing data and secrets.
In a production deployment, these directories should live outside of the checkout, of course.

Now, we create the directories for data storage.

```bash session
$ mkdir -p .dev/volumes/{minio,varfish-static}/data
```

Next, we setup some "secrets" for the passwords.

```bash session
$ mkdir -p .dev/secrets
$ echo db-password >.dev/secrets/db-password
$ echo minio-root-password >.dev/secrets/minio-root-password
$ echo minio-varfish-password >.dev/secrets/minio-varfish-password
```

We now copy the `env.tpl` file to the default location for the environment `.env`.

```bash session
$ cp env.tpl .env
```

Next, create a `docker-compose.override.yml` with the contents of the file `docker-compose.override.yml-dev`.
This will disable everything that we assume is running on your host when you are developing.
This includes the VarFish web server, redis, celery workers, postgres.

```bash session
$ cp docker-compose.override.yml-dev docker-compose.override.yml
```

### Download Dev Data

Now you need to obtain the data to serve by the mehari, viguno, and annonars container.
For this, we have prepared strongly reduced data sets (overall less than 2GB rather than hundreds of GB of data).
Obtain the annonars data:

```bash session
$ mkdir -p .dev/volumes/varfish-static/data/download
$ SRC_DST="
  full/annonars/gnomad-mtdna-grch37-3.1+0.12.7/*:annonars/gnomad-mtdna-grch37-3.1+0.12.7
  full/annonars/gnomad-mtdna-grch38-3.1+0.12.7/*:annonars/gnomad-mtdna-grch38-3.1+0.12.7
  full/annonars/helixmtdb-grch37-20200327+0.12.7/*:annonars/helixmtdb-grch37-20200327+0.12.7
  full/annonars/helixmtdb-grch38-20200327+0.12.7/*:annonars/helixmtdb-grch38-20200327+0.12.7
  full/annonars/genes-3.1+2.1.1+4.4+20230624+0.7.0/*:annonars/genes-3.1+2.1.1+4.4+20230624+0.7.0
  full/mehari/genes-txs-grch37-0.2.2/*:mehari/genes-txs-grch37-0.2.2
  full/mehari/genes-txs-grch38-0.2.2/*:mehari/genes-txs-grch38-0.2.2
  full/mehari/genes-xlink-20230624:mehari/genes-xlink-20230624
  full/tracks/*:tracks
  full/worker/*:worker
  reduced-dev/annonars/*:annonars
  reduced-dev/mehari/*:mehari
  reduced-dev/viguno/*:viguno
"
$ (set -x; for src_dst in $SRC_DST; do \
    src=$(echo $src_dst | cut -d : -f 1); \
    dst=$(echo $src_dst | cut -d : -f 2); \
    mkdir -p .dev/volumes/varfish-static/data/download/$dst; \
    s5cmd \
      --endpoint-url=https://ceph-s3-public.cubi.bihealth.org \
      --no-sign-request \
      sync \
        "s3://varfish-public/$src" \
        ".dev/volumes/varfish-static/data/download/$dst"; \
  done)
```

Setup symlink structure so the data is at the expected location.

```bash session
##
## annonars
##

mkdir -p .dev/volumes/varfish-static/data/annonars

ln -Tsr .dev/volumes/varfish-static/data/download/annonars/genes-* \
  .dev/volumes/varfish-static/data/annonars/genes

names="cadd dbsnp dbnsfp dbscsnv gnomad-mtdna gnomad-genomes gnomad-exomes helixmtdb cons"; \
for genome in grch37 grch38; do \
  for name in $names; do \
    mkdir -p .dev/volumes/varfish-static/data/annonars/$genome; \
    test -e .dev/volumes/varfish-static/data/$genome/$name || \
      ln -Tsr \
        $(echo .dev/volumes/varfish-static/data/download/annonars/$name-$genome-* \
          | tr ' ' '\n' \
          | tail -n 1) \
        .dev/volumes/varfish-static/data/annonars/$genome/$name; \
  done; \
done

##
## mehari
##

mkdir -p .dev/volumes/varfish-static/data/mehari/grch3{7,8}

ln -Tsr .dev/volumes/varfish-static/data/download/mehari/genes-txs-grch37-*/mehari-data-txs-grch37-*in.zst \
  .dev/volumes/varfish-static/data/mehari/grch37
ln -Tsr .dev/volumes/varfish-static/data/download/mehari/freqs-grch37-* \
  .dev/volumes/varfish-static/data/mehari/grch37/freqs
ln -Tsr .dev/volumes/varfish-static/data/download/mehari/genes-txs-grch38-*/mehari-data-txs-grch38-*.bin.zst \
  .dev/volumes/varfish-static/data/mehari/grch38
ln -Tsr .dev/volumes/varfish-static/data/download/mehari/freqs-grch38-* \
  .dev/volumes/varfish-static/data/mehari/grch38/freqs

##
## viguno
##

ln -Tsr .dev/volumes/varfish-static/data/download/mehari/genes-xlink-20230624/genes-xlink.tsv \
  .dev/volumes/varfish-static/data/hgnc_xlink.tsv
ln -Tsr .dev/volumes/varfish-static/data/download/viguno/hpo-20230606+0.1.6 \
  .dev/volumes/varfish-static/data/hpo

##
## worker
##

mkdir -p .dev/volumes/varfish-static/data/worker/{grch3{7,8}/strucvars/bgdbs,noref/genes}

ln -Tsr .dev/volumes/varfish-static/data/download/worker/bgdb-exac-grch37-*/bgdb-exac.bin \
  .dev/volumes/varfish-static/data/worker/grch37/strucvars/bgdbs/exac.bin
ln -Tsr .dev/volumes/varfish-static/data/download/worker/bgdb-g1k-grch37-phase3v2+0.7.0/bgdb-g1k.bin \
  .dev/volumes/varfish-static/data/worker/grch37/strucvars/bgdbs/g1k.bin
ln -Tsr .dev/volumes/varfish-static/data/download/worker/bgdb-gnomad-grch37-*/bgdb-gnomad.bin \
  .dev/volumes/varfish-static/data/worker/grch37/strucvars/bgdbs/gnomad.bin
ln -Tsr .dev/volumes/varfish-static/data/download/worker/bgdb-dbvar-grch37-*/bgdb-dbvar.bin \
  .dev/volumes/varfish-static/data/worker/grch37/strucvars/bgdbs/dbvar.bin
ln -Tsr .dev/volumes/varfish-static/data/download/worker/bgdb-dbvar-grch38-*/bgdb-dbvar.bin \
  .dev/volumes/varfish-static/data/worker/grch38/strucvars/bgdbs/dbvar.bin
ln -Tsr .dev/volumes/varfish-static/data/download/worker/bgdb-dgv-grch37-*/bgdb-dgv.bin \
  .dev/volumes/varfish-static/data/worker/grch37/strucvars/bgdbs/dgv.bin
ln -Tsr .dev/volumes/varfish-static/data/download/worker/bgdb-dgv-grch38-*/bgdb-dgv.bin \
  .dev/volumes/varfish-static/data/worker/grch38/strucvars/bgdbs/dgv.bin
ln -Tsr .dev/volumes/varfish-static/data/download/worker/bgdb-dgv-gs-grch37-*/bgdb-dgv-gs.bin \
  .dev/volumes/varfish-static/data/worker/grch37/strucvars/bgdbs/dgv-gs.bin
ln -Tsr .dev/volumes/varfish-static/data/download/worker/bgdb-dgv-gs-grch38-*/bgdb-dgv-gs.bin \
  .dev/volumes/varfish-static/data/worker/grch38/strucvars/bgdbs/dgv-gs.bin

ln -Tsr .dev/volumes/varfish-static/data/download/worker/clinvar-strucvars-grch37-*/clinvar-strucvars.bin \
  .dev/volumes/varfish-static/data/worker/grch37/strucvars/clinvar.bin
ln -Tsr .dev/volumes/varfish-static/data/download/worker/clinvar-strucvars-grch38-*/clinvar-strucvars.bin \
  .dev/volumes/varfish-static/data/worker/grch38/strucvars/clinvar.bin

ln -Tsr .dev/volumes/varfish-static/data/download/worker/patho-mms-grch37-*/patho-mms.bed \
  .dev/volumes/varfish-static/data/worker/grch37/strucvars/patho-mms.bin
ln -Tsr .dev/volumes/varfish-static/data/download/worker/patho-mms-grch38-*/patho-mms.bed \
  .dev/volumes/varfish-static/data/worker/grch38/strucvars/patho-mms.bin

mkdir -p .dev/volumes/varfish-static/data/worker/grch3{7,8}/tads

ln -Tsr .dev/volumes/varfish-static/data/download/worker/tads-grch37-dixon2015/hesc.bed \
  .dev/volumes/varfish-static/data/worker/grch37/tads/hesc.bed
ln -Tsr .dev/volumes/varfish-static/data/download/worker/tads-grch38-dixon2015/hesc.bed \
  .dev/volumes/varfish-static/data/worker/grch38/tads/hesc.bed

ln -Tsr .dev/volumes/varfish-static/data/download/worker/genes-xlink-*/genes-xlink.bin \
  .dev/volumes/varfish-static/data/worker/noref/genes/xlink.bin
ln -Tsr .dev/volumes/varfish-static/data/download/worker/acmg-sf-*/acmg_sf.tsv \
  .dev/volumes/varfish-static/data/worker/noref/genes/acmg.tsv
ln -Tsr .dev/volumes/varfish-static/data/download/worker/mim2gene-*/mim2gene.tsv \
  .dev/volumes/varfish-static/data/worker/noref/genes/omim.tsv

mkdir -p .dev/volumes/varfish-static/data/worker/grch3{7,8}/genes

ln -Tsr .dev/volumes/varfish-static/data/download/worker/genes-regions-grch37-*/ensembl_genes.bin \
  .dev/volumes/varfish-static/data/worker/grch37/genes/ensembl_regions.bin
ln -Tsr .dev/volumes/varfish-static/data/download/worker/genes-regions-grch38-*/ensembl_genes.bin \
  .dev/volumes/varfish-static/data/worker/grch38/genes/ensembl_regions.bin

ln -Tsr .dev/volumes/varfish-static/data/download/worker/genes-regions-grch37-*/refseq_genes.bin \
  .dev/volumes/varfish-static/data/worker/grch37/genes/refseq_regions.bin
ln -Tsr .dev/volumes/varfish-static/data/download/worker/genes-regions-grch38-*/refseq_genes.bin \
  .dev/volumes/varfish-static/data/worker/grch38/genes/refseq_regions.bin

mkdir -p .dev/volumes/varfish-static/data/worker/grch3{7,8}/features

ln -Tsr .dev/volumes/varfish-static/data/download/worker/masked-repeat-grch37-*/masked-repeat.bin \
  .dev/volumes/varfish-static/data/worker/grch37/features/masked_repeat.bin
ln -Tsr .dev/volumes/varfish-static/data/download/worker/masked-segdup-grch37-*/masked-segdup.bin \
  .dev/volumes/varfish-static/data/worker/grch37/features/masked_seqdup.bin

ln -Tsr .dev/volumes/varfish-static/data/download/worker/masked-repeat-grch38-*/masked-repeat.bin \
  .dev/volumes/varfish-static/data/worker/grch38/features/masked_repeat.bin
ln -Tsr .dev/volumes/varfish-static/data/download/worker/masked-segdup-grch38-*/masked-segdup.bin \
  .dev/volumes/varfish-static/data/worker/grch38/features/masked_seqdup.bin

##
## tracks
##

mkdir -p .dev/volumes/varfish-static/data/nginx/grch3{7,8}

paths_37=$(find .dev/volumes/varfish-static/data/download/tracks/ -type f -name '*.bed' -or -name '*.bed.gz' | sort | grep grch37)
for path in $paths_37; do
  if [[ -e ${path}.tbi ]]; then
    ln -sr $path ${path}.tbi .dev/volumes/varfish-static/data/nginx/grch37
  else
    ln -sr $path .dev/volumes/varfish-static/data/nginx/grch37
  fi
done

paths_38=$(find .dev/volumes/varfish-static/data/download/tracks/ -type f -name '*.bed' -or -name '*.bed.gz' | sort | grep grch38)
for path in $paths_38; do
  if [[ -e ${path}.tbi ]]; then
    ln -sr $path ${path}.tbi .dev/volumes/varfish-static/data/nginx/grch38
  else
    ln -sr $path .dev/volumes/varfish-static/data/nginx/grch38
  fi
done
```

To create an in-house database:

```bash session
varfish-server-worker db mk-inhouse \
  --path-output-tsv /tmp/inhouse.tsv \
  $(find YOUR_PATH -name '*.gts.tsv.gz' | sort)

varfish-server-worker db to-bin \
  --input-type strucvar-inhouse \
  --path-input /tmp/inhouse.tsv \
  --path-output-bin .dev/volumes/varfish-static/data/worker/grch37/strucvars/inhouse.bin
```

### Setup Configuration

The next step step is to create the configuration files in `.dev/config`.

```bash session
mkdir -p .dev/config/nginx
cp utils/nginx/nginx.conf .dev/config/nginx
```

### Startup and Check

Now, you can bring up the docker compose environment (stop with `Ctrl+C`).

```bash session
$ docker compose up
```

To verify the results, have a look at the following URLs:

- Annonars database infos: http://0.0.0.0:3001/annos/db-info?genome-release=grch37
- Mehari impact prections: http://127.0.0.1:3002/tx/csq?genome-release=grch37&chromosome=17&position=48275363&reference=C&alternative=A
- Viguno for TGDS: http://127.0.0.1:3003/hpo/genes?gene_symbol=TGDS

You should also be able to access the MinIO console on:

- http://localhost:3011/login

The admin user is `minioadmin` and the password is stored in `.dev/secrets/minio-root-password`.

## Service Information

This section describes the services that are started with this Docker Compose.

### Trafik

[Traefik](https://traefik.io/traefik/) is a reverse proxy that is used as the main entry point for all services behind HTTP(S).
The software is well-documented by its creators.
However, it is central to the setup and for much of the additional setup, touching Trafik configuraiton is needed.
We thus summarize some important points here.

- Almost all configuration is done using labels on the `traefik` container itself or other containers.
- In the case of using configuration files, you will have to mount them from the host into the container.
- By default, we use "catch-all" configuration based on regular expressions on the host/domain name.

### Mehari

Mehari (by the VarFish authors) provides information about variants and their effect on individual transcripts.

### Viguno

Viguno (by the VarFish authors) provides HPO/OMIM related information.

### Annonars

Annonars (by the VarFish authors) provides variant annotation from public databases.

### Postgres

We use postgres for the database backend of VarFish.

### Redis

The Redis database is used for key-value store, e.g., for caching and the queues in the VarFish server.

### MinIO

[MinIO](https://min.io/) is an S3-compatible object storage server.
The `docker-compose.yml` file will spin up a (single) container with the name `minio` that is used as (a) an internal file storage for VarFish and (b) can be used to upload data into that is then imported by VarFish.

Further, a container `minio-client` is started that you can attach as shown below.
On startup, the `minio-client` container will automatically create a user `varfish` using the secret `minio-varfish-password` as the password.
Further, it will create a bucket `varfish-server` and give read/write access to the bucket for the user `varfish`.
This is the account that VarFish will use to store data in the bucket.

```bash session
$ docker-compose exec -it minio-client bash -i
```

The alias `minio` is pre-configured to point to the MinIO server.
For example

```bash session
host $ docker exec -it minio-client bash -i
[root@minio-client /]# mc ls minio
[2023-06-20 15:09:08 UTC]     0B varfish-server/
[root@minio-client /]# mc admin user ls minio
enabled    varfish               varfish-bucket-po...
[root@minio-client /]# mc admin user info minio  varfish
AccessKey: varfish
Status: enabled
PolicyName: varfish-bucket-policy
MemberOf: []
```

You can create new users, e.g., for uploading data, as follows.
Note that `the-user` corresponds to an S3 access key while `THE_PASSWORD` corresponds to an S3 secret key.

```bash session
host $ docker exec -it minio-client bash -i
[root@minio-client /]# mc mb minio/the-bucket
Bucket created successfully `minio/the-bucket`.
[root@minio-client /]# mc admin user add minio the-user THE_PASSWORD
Added user `the-user` successfully.
[root@minio-client /]# sed -e "s/__BUCKET__/the-bucket/g" \
    /opt/minio-utils/bucket-user-policy.json.tpl \
    > /tmp/the-user-bucket-policy.json
[root@minio-client /]# cat /tmp/the-user-bucket-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
            "s3:ListBucket",
            "s3:PutObject",
            "s3:GetObject",
            "s3:DeleteObject"
        ],
      "Effect": "Allow",
      "Resource": [
        "arn:aws:s3:::the-bucket/*",
        "arn:aws:s3:::the-bucket"
      ],
      "Sid": "BucketAccessForUser"
    }
  ]
}
[root@minio-client /]# mc admin policy create minio the-user-bucket-policy /tmp/the-user-bucket-policy.json
Created policy `the-user-bucket-policy` successfully.
[root@minio-client /]# mc admin policy attach minio the-user-bucket-policy --user the-user
Attached Policies: [the-user-bucket-policy]
To User: the-user
```

## Developer Info

### Managing GitHub Project with Terraform

```bash session
$ export GITHUB_OWNER=bihealth
$ export GITHUB_TOKEN=ghp_<thetoken>

$ cd utils/terraform
$ terraform init
$ terraform import github_repository.varfish-docker-compose-ng varfish-docker-compose-ng

$ terraform validate
$ terraform fmt
$ terraform plan
$ terraform apply
```
