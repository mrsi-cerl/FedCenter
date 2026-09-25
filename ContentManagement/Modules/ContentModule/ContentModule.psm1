# Pull all functions together to make available to others
$funcs = Get-ChildItem -Path "$PSScriptRoot/Public/*.ps1" -Recurse

# Dot-soruce each file to load them
foreach ($file in $funcs) {
  Write-Host "Importing file: ", $file
  . $file.FullName
}

#region Constants

$script:PROGRAM_AREAS = [ordered]@{
  "Acquisition"                            = @(
    "Award Winners",
    "Case Studies",
    "Contract and Procurement Language",
    "Databases and Software Tools",
    "Directories, Catalogs, and Newsletters",
    "Executive Orders",
    "Guidance",
    "Laws, Regulations, and Agreements",
    "Libraries and Repositories",
    "Organizations and Programs",
    "Purchasing Guides",
    "Training, Presentations, and Briefings"
  )
  "Chemical Management"                    = @(
    "Accident Prevention & Reporting",
    "Award Winners",
    "Case Studies",
    "Chemical Identification",
    "Chemical Use Reduction",
    "Community Right-to-Know",
    "Databases and Software Tools",
    "Directories/Catalogs/Newsletters",
    "Libraries and Repositories",
    "Organizations",
    "Regulations, Guidance, and Policy",
    "Training, Presentations, and Briefings"
  )
  "Cleanup"                                = @(
    "Award Winners",
    "BRAC",
    "Brownfields",
    "Databases and Software Tools",
    "Directories, Catalogs, and Newsletters",
    "General",
    "Libraries and Repositories",
    "Munitions",
    "New Technology",
    "NPL",
    "Organizations",
    "Post Construction Completion",
    "Property Re-use",
    "Quality Assurance",
    "Regulations, Guidance, and Policy",
    "Remediation",
    "Substances of Concern",
    "Superfund Task Force",
    "Training, Presentations, and Briefings"
  )
  "Climate Resilience"                     = @(
    "Agency-Specific Climate Change/Adaptation",
    "Case Studies",
    "Coastal Zones",
    "Construction Design",
    "Databases and Software Tools",
    "Directories, Catalogs, and Newsletters",
    "Federal",
    "Libraries and Repositories",
    "Organizations and Programs",
    "Training, Presentations, and Briefings",
    "Water"
  )
  "Cultural Resources"                     = @(
    "Award Winners",
    "Case Studies",
    "Databases and Software Tools",
    "Directories, Catalogs, and Newsletters",
    "Federal Agency Policy",
    "Implementation Guidance",
    "International Agreements",
    "Libraries and Repositories",
    "National Executive Orders",
    "National Laws and Statutes"
    "Organizations and Programs"
    "Training, Presentations, and Briefings"
  )
  "Electronics Stewardship"                = @(
    "Acquisition",
    "Databases and Software Tools",
    "Disposal",
    "Libraries and Repositories",
    "Organizations",
    "Regulations, Guidance, and Policy",
    "Training, Presentations, and Briefings"
  )
  "Energy"                                 = @(
    "Alternative Energy",
    "Award Winners",
    "Case Studies",
    "Data Centers",
    "Databases and Software Tools",
    "Directories, Catalogs, and Newsletters",
    "Energy Conservation",
    "Executive Orders",
    "Federal Legislation and Policy",
    "Guidance Documents",
    "Libraries and Repositories",
    "Organizations and Programs",
    "Training, Presentations, and Briefings"
  )
  "Environmental Compliance"               = @(
    "Compliance Auditing",
    "Databases and Software Tools",
    "Directories, Catalogs, and Newsletters",
    "DOD Environmental Standards for Substantial Installations in Foreign Countries",
    "Enforcement",
    "Federal Regulations",
    "General",
    "Guidance for CERCLA",
    "Guidance for EPA Programs",
    "Guidance for EPCRA",
    "Guidance for FIFRA",
    "Guidance for RCRA",
    "Guidance for RCRA, Subtitle C",
    "Guidance for RCRA, Subtitle I",
    "Guidance for the Clean Air Act (CAA)",
    "Guidance for the Clean Water Act (CWA)",
    "Guidance for the Safe Drinking Water Act (SDWA)",
    "Guidance for TSCA",
    "Libraries and Repositories",
    "Organizations",
    "State Regulations",
    "Training, Presentations, and Briefings"
  )
  "Environmental Management Systems (EMS)" = @(
    "Award Winners",
    "Directories, Catalogs, and Newsletters",
    "EMS Development",
    "EMS Examples and Case Studies",
    "EPA Guidance",
    "Executive Orders",
    "Federal Agency Guidance and Policies",
    "International Standards Organization (ISO)",
    "Libraries and Repositories",
    "Organizations",
    "Training, Presentations, and Briefings"
  )
  "Greenhouse Gases"                       = @(
    "Case Studies",
    "Conferences and Events",
    "Databases and Software Tools",
    "Directories, Catalogs, and Newsletters",
    "International",
    "Inventories",
    "Libraries and Repositories",
    "National",
    "Organizations and Programs",
    "Regional",
    "Training, Presentations, and Briefings"
  )
  "High Performance Buildings"             = @(
    "Agency-specific Policy",
    "Award Winners",
    "Beneficial Landscaping",
    "Case Studies",
    "Conferences and Events",
    "Construction Design",
    "Construction Guidelines and Criteria",
    "Databases and Software Tools",
    "Directories, Catalogs, and Newsletters",
    "Guidance & Policy",
    "Guiding Principles and LEED",
    "Indoor Air Quality",
    "Libraries and Repositories",
    "Organizations and Programs",
    "Planning",
    "Training, Presentations, and Briefings"
  )
  "Natural Resources"                      = @(
    "Water Conservation",
    "Award Winners",
    "Coastal Zones",
    "Databases and Software Tools",
    "Directories, Catalogs, and Newsletters",
    "Endangered/Threatened Species",
    "General",
    "Land Management",
    "Libraries and Repositories",
    "Organizations",
    "Species Management",
    "Training, Presentations, and Briefings",
    "Water Resources",
    "Watershed Management",
    "Wetlands",
    "Wetlands Management",
    "Wildlife Management"
  )
  "NEPA"                                   = @(
    "CEQ"
    "Databases and Software Tools",
    "Directories, Catalogs, and Newsletters",
    "Executive Orders and Laws",
    "Lessons Learned",
    "Libraries and Repositories",
    "Organizations and Programs",
    "Other Guidance",
    "Training, Presentations, and Briefings"
  )
  "PFAS"                                   = @(
    "Databases and Software Tools",
    "Federal Agency Resources",
    "Guidance",
    "Libraries, Repositories, and Research",
    "Organizations and Programs",
    "Proposed and Final Legislation",
    "State, National, and International Regulations",
    "Training, Presentations and Briefings"
  )
  "Pollution Prevention"                   = @(
    "Case Studies",
    "Databases and Software Tools",
    "Directories, Catalogs, and Newsletters",
    "Electronics",
    "Grounds Maintenance Pollution Prevention",
    "Household Pollution Prevention",
    "Libraries and Repositories",
    "Medical Facilities Pollution Prevention",
    "Organizations",
    "Recycling and Reuse",
    "Regulations, Guidance, and Policy",
    "Training, Presentations, and Briefings",
    "Waste Reduction"
  )
  "Sustainability"                         = @(
    "Award Winners",
    "Case Studies",
    "Databases and Software Tools",
    "Directories, Catalogs, and Newsletters",
    "Federal Agreements and Guidance",
    "Federal Executive Orders and Legislation",
    "Federal Facilities",
    "General",
    "Infrastructure",
    "International Agreements",
    "Libraries and Repositories",
    "Municipalities",
    "Organizations",
    "Property Disposal",
    "Research and Technical Reports",
    "Sustainability Integration or 'Crosswalks'",
    "Training, Presentations, and Briefings"
  )
  "Transportation"                         = @(
    "Acquisition",
    "Case Studies",
    "Databases and Software Tools",
    "Directories, Catalogs, and Newsletters",
    "Fleet Management",
    "Freight, Cargo, and Household Goods",
    "Greenhouse Gases",
    "Guidance",
    "Legislation",
    "Libraries and Repositories",
    "Organizations",
    "Petroleum Alternatives",
    "Pollution Prevention Opportunities",
    "Training, Presentations, and Briefings"
  )
  "Water Efficiency"                       = @(
    "Case Studies",
    "Databases and Software Tools",
    "Directories, Catalogs, and Newsletters",
    "Implementation Guidance",
    "Libraries and Repositories",
    "Management Practices",
    "Organizations and Programs",
    "Regulations, Guidance, and Policy",
    "Training, Presentations, and Briefings"
  )
}

#endregion

Export-ModuleMember -Function * -Variable PROGRAM_AREA