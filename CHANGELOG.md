# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Added
- Comprehensive `.gitignore` for Python, PowerShell, and heavy binaries.
- Professional architecture diagrams detailing the C4 Model (`ARCHITECTURE.md`).
- Quality assurance protocols and standard validations (`REGRESSION_PLAN.md`).
- Future roadmap and stabilization milestones (`NEXT_STEPS.md`).
- This `CHANGELOG.md` file.

### Changed
- Standardized documentation in the base repository to prepare for open-source and CI/CD integrations.
- Adjusted `README.md` to reference the newly constructed technical documents.

## [1.0.0] - 2026-04-25
### Added
- Initial deployment bundles for the UAP Edge AI 3-Tier Station.
- AMB82-Mini edge vision inference scripts (Tier 1).
- Raspberry Pi 2 W gatekeeper daemon (`uap_gatekeeper.py`) and WoL mechanisms (Tier 2).
- Raspberry Pi 5 Hailo-8L heavy inference templates (`capture_uap.sh`, `hailo_infer.py`) (Tier 3).
- PowerShell-based cross-device automation and SD Card Imaging setup utilities.
