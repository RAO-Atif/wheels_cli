/**
 * Set the datasource configuration
 *
 * {code:bash}
 * wheels set datasource myapp
 * wheels set datasource myapp_prod --environment=production
 * {code}
 */
component extends="../base" {

	/**
	 * @datasourceName The name of the datasource to use
	 * @environment Optional environment to set the datasource for (default: current)
	 * @help Set the datasource configuration
	 */
	public void function run(
		required string datasourceName,
		string environment = ""
	) {
		local.appPath = getCWD();
		
		if (!isWheelsApp(local.appPath)) {
			error("This command must be run from a Wheels application directory");
			return;
		}

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
	 	local.filePath = local.appPath & "/config/settings.cfm";
        local.fileContent = fileRead(local.filePath);
		local.targetPattern = '(?mi)^\s*set\s*\(\s*dataSourceName\s*=\s*["''].*?["'']\s*\)\s*;?';
		if (reFindNoCase(local.targetPattern, local.fileContent)) {
		local.updatedContent = reReplaceNoCase(
			local.fileContent,
			local.targetPattern,
				chr(9) & 'set(dataSourceName="#arguments.datasourceName#");',
				"one"
			);

			fileWrite(local.filePath, local.updatedContent);
			print.boldGreenLine("Datasource replaced successfully");
			return;
		}
		local.newPattern = '(?mi)^(\s*//\s*CLI-Appends Here)';

		if (reFindNoCase(local.newPattern, local.fileContent)) {

			local.updatedContent = reReplaceNoCase(
			local.fileContent,
			local.newPattern,
				'\1' & chr(13) & chr(10) & chr(9) &
				'set(dataSourceName="#arguments.datasourceName#");',
				"one"
			);

			fileWrite(local.filePath, local.updatedContent);
			print.boldGreenLine("Datasource added successfully");
			return;
		}
		local.cfscriptCloseTag = "<" & "/cfscript>";
		local.insertPosition  = findNoCase(local.cfscriptCloseTag, local.fileContent);

		if (local.insertPosition > 0) {

			local.updatedContent =
				left(local.fileContent, local.insertPosition - 1) &
				chr(13) & chr(10) &
				chr(9) & 'set(dataSourceName="#arguments.datasourceName#");' &
				chr(13) & chr(10) &
				mid(local.fileContent, local.insertPosition);

			fileWrite(local.filePath, local.updatedContent);
			print.boldGreenLine("Datasource added inside " & local.filePath);
		}
		else {
			print.RedLine("No" & local.cfscriptCloseTag & " tag found in setting file");
		}
		
		return;
	
			// Use the set settings functionality
		
			local.settingsCommand = CreateObject("component", "settings");
			local.settingsCommand.setShell(shell);
			local.settingsCommand.setPrint(print);
			
			// Set the dataSourceName setting
			local.settingsCommand.run(
				settingName = "dataSourceName",
				value = arguments.datasourceName,
				environment = arguments.environment
			);
			
			print.line();
			print.boldGreenLine("Datasource set to: " & arguments.datasourceName);
			
			// Additional datasource validation if server is running
			try {
				// Try to get datasource info from running server
				local.serverDetails = serverService.resolveServerDetails(serverProps = {webroot = getCWD()});
				if (StructKeyExists(local.serverDetails, "serverInfo") && 
				    StructKeyExists(local.serverDetails.serverInfo, "datasources") &&
				    StructKeyExists(local.serverDetails.serverInfo.datasources, arguments.datasourceName)) {
					print.greenLine("Datasource exists in server configuration");
				} else {
					print.yellowLine("Warning: Unable to verify datasource '" & arguments.datasourceName & "' in server configuration");
					print.line("You may need to create this datasource in your CFML server admin");
				}
			} catch (any e) {
				// Server might not be running, skip validation
				print.line("Note: Unable to verify datasource configuration (server may not be running)");
			}
	
		} catch (any e) {
			error("Error setting datasource: " & e.message);
		}
	}

	private string function getEnvironment(required string appPath) {
		// Same logic as get environment command
		local.environment = "";
		
		// Check .env file
		local.envFile = arguments.appPath & "/.env";
		if (FileExists(local.envFile)) {
			local.envContent = FileRead(local.envFile);
			local.envMatch = REFind("(?m)^WHEELS_ENV\s*=\s*(.+)$", local.envContent, 1, true);
			if (local.envMatch.pos[1] > 0) {
				local.environment = Trim(Mid(local.envContent, local.envMatch.pos[2], local.envMatch.len[2]));
			}
		}

		// Check environment variable
		if (!Len(local.environment)) {
			local.sysEnv = CreateObject("java", "java.lang.System");
			local.wheelsEnv = local.sysEnv.getenv("WHEELS_ENV");
			if (!IsNull(local.wheelsEnv) && Len(local.wheelsEnv)) {
				local.environment = local.wheelsEnv;
			}
		}
		
		// Default to development
		if (!Len(local.environment)) {
			local.environment = "development";
		}
		
		return local.environment;
	}
	


}
