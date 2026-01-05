/**
 * Set a specific configuration value
 *
 * {code:bash}
 * wheels set settings cacheQueries false
 * wheels set settings dataSourceName myapp
 * wheels set settings errorEmailAddress admin@example.com
 * {code}
 */
component extends="../base" {

	/**
	 * @settingName The name of the setting to set
	 * @value The value to set (use true/false for booleans)
	 * @environment Optional environment to set the setting for (default: current)
	 * @help Set a specific configuration value
	 */
	public void function run(
		required string settingName,
		required string value,
		string environment = ""
	) {
		local.appPath = getCWD();

		if (!isWheelsApp(local.appPath)) {
			error("This command must be run from a Wheels application directory");
			return;
		}
		local.appPath = getCWD();


		try {
			// Determine environment
			if (!Len(arguments.environment)) {
				arguments.environment = getEnvironment(local.appPath);
			}

			// Validate environment
			local.validEnvironments = ["development", "testing", "maintenance", "production"];
			if (!ArrayFindNoCase(local.validEnvironments, arguments.environment)) {
				error("Invalid environment: #arguments.environment#");
				return;
			}

			local.environment = getEnvironment(local.appPath);
			writeOutput("Current environment detected: " & local.environment & Chr(10));

			local.configDir = local.appPath & "/config/";
			switch (local.environment) {
				case "development":
					local.settingsFile = local.configDir & "development/settings.cfm";
					break;
				case "testing":
					local.settingsFile = local.configDir & "testing/settings.cfm";
					break;
				case "production":
					local.settingsFile = local.configDir & "production/settings.cfm";
					break;
				case "maintenance":
					local.settingsFile = local.configDir & "maintenance/settings.cfm";
					break;
				default:
					local.settingsFile = local.configDir & "settings.cfm";
			}
			print.line("Settings file to update: " & local.settingsFile & Chr(10));


			if (!FileExists(local.settingsFile)) {
				print.line("Settings file not found for environment: " & local.environment & Chr(10));
				return;
			}

			local.fileContent = FileRead(local.settingsFile);

			if (CompareNoCase(arguments.value, "true") == 0 || CompareNoCase(arguments.value, "false") == 0) {
				local.newValue = LCase(arguments.value); 
			} else if (IsNumeric(arguments.value)) {
				local.newValue = arguments.value;
			} else {
				local.newValue = '"' & Replace(arguments.value, '"', '""', "all") & '"'; 
			}

			local.pattern =
                       "(?mi)^\s*set\s*\(\s*" & arguments.settingName & "\s*=\s*[^;\r\n]*\s*\)\s*;";
			local.newLine = "    set(" & arguments.settingName & " = " & local.newValue & ");";

			if (REFindNoCase(local.pattern, local.fileContent)) {			
				local.finalContent = REReplaceNoCase(
					local.fileContent,
					local.pattern,
					local.newLine,
					"all"
				);

				FileWrite(local.settingsFile, local.finalContent);
				print.line("Updated setting: " & arguments.settingName & " = " & local.newValue & Chr(10));

			} else {
				
				local.cfscriptCloseTag = "<" & "/cfscript>";
				local.insertPos = FindNoCase(local.cfscriptCloseTag, local.fileContent);

				if (local.insertPos GT 0) {

					local.finalContent =
						Left(local.fileContent, local.insertPos - 1) &
						Chr(13) & Chr(10) &
						local.newLine &
						Chr(13) & Chr(10) &
						Mid(local.fileContent, local.insertPos);

					FileWrite(local.settingsFile, local.finalContent);
					print.line("Inserted setting: " & arguments.settingName & " = " & local.newValue & Chr(10));

				} else {
					print.cyanLine("<" & "cfscript> tag found in settings file");
				}
			}
			
			
			// Create directory if it doesn't exist
			local.settingsDir = GetDirectoryFromPath(local.settingsFile);
			if (!DirectoryExists(local.settingsDir)) {
				print.line("The environment directory doesn't exist yet.");
				print.line("Create it with: mkdir " & local.settingsDir);
				print.line();
			}
			
			if (!FileExists(local.settingsFile)) {
				print.line("If the file doesn't exist, create it with this content:");
				print.line();
				print.cyanLine("<" & "cfscript>");
				print.cyanLine("    set(" & arguments.settingName & " = " & local.formattedValue & ");");
				print.cyanLine("</" & "cfscript>");
			}
			
			print.line();
			print.yellowLine("After making the change, reload your application with:");
			print.line("wheels reload " & arguments.environment);

		} catch (any e) {
			error("Error: " & e.message);
			if (StructKeyExists(e, "detail") && Len(e.detail)) {
				error("Details: " & e.detail);
			}
		}
	}


	private string function formatValue(required string value) {
		// Handle boolean values
		if (arguments.value == "true" || arguments.value == "false") {
			return arguments.value;
		}

		// Handle numeric values
		if (IsNumeric(arguments.value)) {
			return arguments.value;
		}

		// Handle empty string
		if (!Len(arguments.value)) {
			return '""';
		}

		// String value - escape quotes and wrap in quotes
		local.escaped = Replace(arguments.value, '"', '""', "all");
		return '"' & local.escaped & '"';
	}
}