# Development Tips & Tricks

## Quick start

```shell
mkdir site-modules && ln -s ../ site-modules/patching
vagrant up centos
bolt task run facts --targets vagrant_centos
```

## Ideology

We've setup this repo to be used with the following:
 * bolt
 * vagrant

The repo itself is a `boltdir`, so you should be able to run command such as `bolt task show`
and see a list of tasks. This works by having a `bolt.yaml` in the root directory pointing
at `site-modules` which has a symlink back to this repo's directory.

To test on some servers, you can use Vagrant to spin up new boxes:

```shell
# spin up a CentOS 7 box
BOX=centos/7 vagrant up centos

# spin up a CentOS 8 box
BOX=generic/centos8 vagrant up centos

# spin up a Ubuntu 16.04 box
BOX=generic/ubuntu1604 vagrant up ubuntu

# spin up a Ubuntu 18.04 box
BOX=generic/ubuntu1804 vagrant up ubuntu
```

The `bolt/inventory.yaml` file then contains host entries for both the `centos` and `ubuntu`
vagrant boxes, along with paths to the proper Vagrant SSH keys.

You can test out bolt tasks/plans on them by doing something like:
```shell
bolt task run facts --targets vagrant_centos
bolt task run facts --targets vagrant_ubuntu
```
