# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Changed
- removed description and discussion from Logo structure
- removed isDistributed from Backer structure
- removed setSplitsAddress()
- removed "_amount" argument from withdrawFunds
- upgraded openzeppelin contracts version from ^4.9.2 to ^5.0.2
- made DLogos upgradeable
### Added
- logoRewards variable to avoid loops in Dlogos
- logoRejectedFunds variable to avoid loops in Dlogos
- pause() and unpause() in Dlogos
- Error.sol
- deployment and upgrade scripts

## [2.0.1] - 2024-06-03
### Added
- hardhat env
