# Copyright (c) 2024 SolarWinds, LLC.
# All rights reserved.

require 'json'

scan_report_path = '../../../reports/report.checks.json'
if File.exist?(scan_report_path)
	content = File.read(scan_report_path)
	parsed_data = JSON.parse(content)
	assessments = parsed_data['report']['scans']['scan-version']['assessments']

	assessments.each do |key, value|
		if value['status'] != 'pass'
			puts "Found issue. Please check https://my.secure.software/."
			exit(1)
		end
	end
else
	puts "Missing scanned report."
	exit(1)
end

exit(0)
