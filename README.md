#  sync-vhd script

[![GitHub release (latest SemVer)](https://img.shields.io/github/v/release/aosterwyk/sync-vhd?sort=semver)](https://github.com/aosterwyk/sync-vhd/releases) [![GitHub last commit](https://img.shields.io/github/last-commit/aosterwyk/sync-vhd)](https://github.com/aosterwyk/sync-vhd/commits/master) [![Discord](https://img.shields.io/discord/90687557523771392?color=000000&label=%20&logo=discord)](https://discord.gg/QNppY7T) 

This script downloads the newest version of disk2vhd and creates a VHD file for volumes. It can be used as a scheduled task exisiting VHDs will be renamed with a timestamp which is useful for keeping virtual disks up to date. 

## Installation

- Download and run the script

## Usage

All switches are optional. The script will default to the OS drive as a source and prompt for the destination drive.

**NoUpdate**: Disable checking for disk2vhd updates

**destinationDrive** <drive letter>: Where to save VHD file. This will default to "<drive letter>:\VHDs". You do not need to use the destinationPath switch with option. 

**destinationPath** <path>: Override default ("<drive letter>:\VHDs") path

**sourceDrive** <drive letter>: Override default (OS, usually C) source drive

## Support

[Discord server](https://discord.gg/QNppY7T) or DM `VariXx`

## License
[Apache License 2.0](https://choosealicense.com/licenses/apache-2.0/)
