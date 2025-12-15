/**
 * Clear application caches
 * 
 * This command clears various types of caches used by Wheels including query, page,
 * partial, action, and SQL caches. Clear specific caches or all at once.
 * 
 * {code:bash}
 * wheels cache:clear
 * wheels cache:clear all force=true
 * wheels cache:clear query
 * wheels cache:clear page
 * wheels cache:clear partial
 * wheels cache:clear action
 * wheels cache:clear sql
 * {code}
 **/
component extends="../base" {
	
	property name="FileSystemUtil" inject="FileSystem";
	
	// CommandBox metadata
	this.aliases = [ "clear", "flush" ];
	this.parameters = [
		{ name="name", type="string", required=false, default="all", hint="Cache name to clear (query|page|partial|action|sql|all)" },
		{ name="force", type="boolean", required=false, default=false, hint="Skip confirmation for clearing all caches" }
	];
	
	/**
	 * Clear specific or all application caches
	 * 
	 * This command clears various types of caches used by Wheels:
	 * - query: Database query cache
	 * - page: Full page cache
	 * - partial: Partial/fragment cache
	 * - action: Action cache
	 * - sql: SQL file cache
	 * - all: Clear all caches (default)
	 * 
	 * @name Cache name to clear (query|page|partial|action|sql|all)
	 * @force Skip confirmation for clearing all caches
	 **/
	function run(
		string name = "all",
		boolean force = false
	) {
		if (!isWheelsApp()) {
			error("This command must be run from a Wheels application root directory.");
		}
		
		// Updated to include logs
		var validCaches = ["query", "page", "partial", "action", "sql", "logs", "all"];
		
		if (!arrayContainsNoCase(validCaches, arguments.name)) {
			print.redLine("Invalid cache name: #arguments.name#");
			print.line("Valid options are: #arrayToList(validCaches, ', ')#");
			return;
		}
		
		var serverInfo = $getServerInfo();
		var serverType = determineServerType(serverInfo);

		var cacheBasePath = getServerCachePath(serverType, serverInfo);
		
		print.boldGreenLine("==> Clearing #arguments.name# cache(s) from #serverType# server...");
		print.line("Cache path: #cacheBasePath#");
		print.line();
		
		// Warn if clearing all caches including logs
		if ((arguments.name == "all" || arguments.name == "logs") && !arguments.force) {
			print.yellowLine("WARNING: This will clear application caches" & 
				(arguments.name == "all" || arguments.name == "logs" ? " and log files" : "") & 
				" at the server level.");
			if (!confirm("Are you sure you want to continue?")) {
				print.line("Operation cancelled.");
				return;
			}
			print.line();
		}
		
		var clearedCaches = [];
		
		// Clear specific cache or all caches
		if (arguments.name == "all") {
			clearedCaches.append(clearQueryCache(cacheBasePath, serverType));
			clearedCaches.append(clearPageCache(cacheBasePath, serverType));
			clearedCaches.append(clearPartialCache(cacheBasePath, serverType));
			clearedCaches.append(clearActionCache(cacheBasePath, serverType));
			clearedCaches.append(clearSQLCache(cacheBasePath, serverType));
			clearedCaches.append(clearLogFiles(serverInfo, serverType));
		} else {
			switch(arguments.name) {
				case "query":
					clearedCaches.append(clearQueryCache(cacheBasePath, serverType));
					break;
				case "page":
					clearedCaches.append(clearPageCache(cacheBasePath, serverType));
					break;
				case "partial":
					clearedCaches.append(clearPartialCache(cacheBasePath, serverType));
					break;
				case "action":
					clearedCaches.append(clearActionCache(cacheBasePath, serverType));
					break;
				case "sql":
					clearedCaches.append(clearSQLCache(cacheBasePath, serverType));
					break;
				case "logs":
					clearedCaches.append(clearLogFiles(serverInfo, serverType));
					break;
			}
		}
		
		// Display results
		print.line();
		print.boldGreenLine("==> Cache clearing complete!");
		
		for (var result in clearedCaches) {
			if (result.success) {
				print.greenLine("    #result.cache# cleared (#result.details#)");
			} else {
				print.yellowLine("    #result.cache#: #result.details#");
			}
		}
	}
	
	
	/**
	 * Determine server type from server info
	 */
	private string function determineServerType(required struct serverInfo) {
		// Check server name/version info to determine if it's Lucee or Adobe
		if (structKeyExists(arguments.serverInfo, "serverName")) {
			if (findNoCase("lucee", arguments.serverInfo.serverName)) {
				return "lucee";
			} else if (findNoCase("coldfusion", arguments.serverInfo.serverName) || 
					   findNoCase("adobe", arguments.serverInfo.serverName)) {
				return "adobe";
			}
		}
		
		// Try to detect by checking for Lucee-specific or Adobe-specific features
		try {
			// Check for Lucee-specific function
			if (isDefined("server.lucee")) {
				return "lucee";
			}
		} catch (any e) {
			// Not Lucee
		}
		
		try {
			// Check for Adobe ColdFusion specific
			if (isDefined("server.coldfusion")) {
				return "adobe";
			}
		} catch (any e) {
			// Not Adobe
		}
		
		// Default to lucee if unable to determine
		print.yellowLine("Unable to determine server type, defaulting to Lucee paths");
		return "lucee";
	}
	
	/**
	 * Get the server cache base path based on server type
	 */
	private string function getServerCachePath(required string serverType, required struct serverInfo) {
		var basePath = "";
		
		if (arguments.serverType == "lucee") {
			// Lucee cache paths
			// First try to get from server context
			if (isDefined("server.lucee.version")) {
				// Try common Lucee cache locations
				var possiblePaths = [
					expandPath("{lucee-server}/cache"),
					expandPath("{lucee-web}/cache"),
					"/opt/lucee/server/lucee-server/cache",
					"/var/opt/lucee/server/lucee-server/cache",
					fileSystemUtil.resolvePath("WEB-INF/lucee/cache")
				];
				
				for (var path in possiblePaths) {
					if (directoryExists(path)) {
						return path;
					}
				}
			}
			
			// Fall back to WEB-INF location
			basePath = fileSystemUtil.resolvePath("WEB-INF/lucee/cache");
		} else {
			// Adobe ColdFusion cache paths
			// Try common Adobe CF cache locations
			var possiblePaths = [
				expandPath("{cf-runtime}/cache"),
				"/opt/coldfusion/cfusion/cache",
				"/opt/coldfusion2023/cfusion/cache",
				"/opt/coldfusion2021/cfusion/cache",
				"C:/ColdFusion2023/cfusion/cache",
				"C:/ColdFusion2021/cfusion/cache",
				fileSystemUtil.resolvePath("WEB-INF/cfusion/cache")
			];
			
			for (var path in possiblePaths) {
				if (directoryExists(path)) {
					return path;
				}
			}
			
			// Fall back to WEB-INF location
			basePath = fileSystemUtil.resolvePath("WEB-INF/cfusion/cache");
		}
		
		// If cache directory doesn't exist at server level, fall back to app level
		if (!directoryExists(basePath)) {
			print.yellowLine("Server cache directory not found, using application-level cache");
			basePath = fileSystemUtil.resolvePath("tmp/cache");
		}
		
		return basePath;
	}
	
	/**
	 * Clear query cache
	 */
	private struct function clearQueryCache(required string basePath, required string serverType) {
		var result = {
			cache: "Query",
			success: false,
			details: ""
		};
		
		try {
			var cacheDir = "";
			
			if (arguments.serverType == "lucee") {
				// Lucee stores query cache differently
				cacheDir = arguments.basePath & "/query";
				if (!directoryExists(cacheDir)) {
					cacheDir = arguments.basePath;
				}
			} else {
				// Adobe CF query cache location
				cacheDir = arguments.basePath & "/queries";
				if (!directoryExists(cacheDir)) {
					cacheDir = arguments.basePath & "/query";
				}
			}
			
			// Fall back to app-level if server cache not found
			if (!directoryExists(cacheDir)) {
				cacheDir = fileSystemUtil.resolvePath("tmp/cache/queries");
			}
			
			if (directoryExists(cacheDir)) {
				var files = directoryList(cacheDir, true, "query", "*.cache|*.tmp");
				var fileCount = 0;
				
				for (var file in files) {
					if (file.type == "File") {
						try {
							fileDelete(file.directory & "/" & file.name);
							fileCount++;
						} catch (any e) {
							// Skip files that can't be deleted (locked, etc.)
						}
					}
				}
				
				result.success = true;
				result.details = "#fileCount# cached queries cleared from #cacheDir#";
			} else {
				result.success = true;
				result.details = "No query cache directory found";
			}
		} catch (any e) {
			result.details = "Error: #e.message#";
		}
		
		return result;
	}
	
	/**
	 * Clear page cache
	 */
	private struct function clearPageCache(required string basePath, required string serverType) {
		var result = {
			cache: "Page",
			success: false,
			details: ""
		};
		
		try {
			var cacheDir = "";
			
			if (arguments.serverType == "lucee") {
				cacheDir = arguments.basePath & "/page";
				if (!directoryExists(cacheDir)) {
					cacheDir = arguments.basePath & "/template";
				}
			} else {
				cacheDir = arguments.basePath & "/pages";
				if (!directoryExists(cacheDir)) {
					cacheDir = arguments.basePath & "/template";
				}
			}
			
			// Fall back to app-level if server cache not found
			if (!directoryExists(cacheDir)) {
				cacheDir = fileSystemUtil.resolvePath("tmp/cache/pages");
			}
			
			if (directoryExists(cacheDir)) {
				var files = directoryList(cacheDir, true, "query", "*.cache|*.class|*.tmp");
				var fileCount = 0;
				var totalSize = 0;
				
				for (var file in files) {
					if (file.type == "File") {
						try {
							totalSize += getFileInfo(file.directory & "/" & file.name).size;
							fileDelete(file.directory & "/" & file.name);
							fileCount++;
						} catch (any e) {
							// Skip locked files
						}
					}
				}
				
				result.success = true;
				result.details = "#fileCount# pages cleared, #formatFileSize(totalSize)# freed";
			} else {
				result.success = true;
				result.details = "No page cache directory found";
			}
		} catch (any e) {
			result.details = "Error: #e.message#";
		}
		
		return result;
	}
	
	/**
	 * Clear partial cache
	 */
	private struct function clearPartialCache(required string basePath, required string serverType) {
		var result = {
			cache: "Partial",
			success: false,
			details: ""
		};
		
		try {
			var cacheDir = "";
			
			if (arguments.serverType == "lucee") {
				cacheDir = arguments.basePath & "/partial";
				if (!directoryExists(cacheDir)) {
					cacheDir = arguments.basePath & "/fragment";
				}
			} else {
				cacheDir = arguments.basePath & "/partials";
				if (!directoryExists(cacheDir)) {
					cacheDir = arguments.basePath & "/fragments";
				}
			}
			
			// Fall back to app-level if server cache not found
			if (!directoryExists(cacheDir)) {
				cacheDir = fileSystemUtil.resolvePath("tmp/cache/partials");
			}
			
			if (directoryExists(cacheDir)) {
				var files = directoryList(cacheDir, true, "query", "*.cache|*.tmp");
				var fileCount = 0;
				
				for (var file in files) {
					if (file.type == "File") {
						try {
							fileDelete(file.directory & "/" & file.name);
							fileCount++;
						} catch (any e) {
							// Skip locked files
						}
					}
				}
				
				result.success = true;
				result.details = "#fileCount# partials cleared";
			} else {
				result.success = true;
				result.details = "No partial cache directory found";
			}
		} catch (any e) {
			result.details = "Error: #e.message#";
		}
		
		return result;
	}
	
	/**
	 * Clear action cache
	 */
	private struct function clearActionCache(required string basePath, required string serverType) {
		var result = {
			cache: "Action",
			success: false,
			details: ""
		};
		
		try {
			var cacheDir = "";
			
			if (arguments.serverType == "lucee") {
				cacheDir = arguments.basePath & "/action";
				if (!directoryExists(cacheDir)) {
					cacheDir = arguments.basePath & "/component";
				}
			} else {
				cacheDir = arguments.basePath & "/actions";
				if (!directoryExists(cacheDir)) {
					cacheDir = arguments.basePath & "/components";
				}
			}
			
			// Fall back to app-level if server cache not found
			if (!directoryExists(cacheDir)) {
				cacheDir = fileSystemUtil.resolvePath("tmp/cache/actions");
			}
			
			if (directoryExists(cacheDir)) {
				var files = directoryList(cacheDir, true, "query", "*.cache|*.class|*.tmp");
				var fileCount = 0;
				
				for (var file in files) {
					if (file.type == "File") {
						try {
							fileDelete(file.directory & "/" & file.name);
							fileCount++;
						} catch (any e) {
							// Skip locked files
						}
					}
				}
				
				result.success = true;
				result.details = "#fileCount# actions cleared";
			} else {
				result.success = true;
				result.details = "No action cache directory found";
			}
		} catch (any e) {
			result.details = "Error: #e.message#";
		}
		
		return result;
	}
	
	/**
	 * Clear SQL file cache
	 */
	private struct function clearSQLCache(required string basePath, required string serverType) {
		var result = {
			cache: "SQL",
			success: false,
			details: ""
		};
		
		try {
			var cacheDir = "";
			
			if (arguments.serverType == "lucee") {
				cacheDir = arguments.basePath & "/sql";
				if (!directoryExists(cacheDir)) {
					cacheDir = arguments.basePath & "/datasource";
				}
			} else {
				cacheDir = arguments.basePath & "/sql";
				if (!directoryExists(cacheDir)) {
					cacheDir = arguments.basePath & "/datasource";
				}
			}
			
			// Fall back to app-level if server cache not found
			if (!directoryExists(cacheDir)) {
				cacheDir = fileSystemUtil.resolvePath("tmp/cache/sql");
			}
			
			if (directoryExists(cacheDir)) {
				var files = directoryList(cacheDir, true, "query", "*.cache|*.sql|*.tmp");
				var fileCount = 0;
				
				for (var file in files) {
					if (file.type == "File") {
						try {
							fileDelete(file.directory & "/" & file.name);
							fileCount++;
						} catch (any e) {
							// Skip locked files
						}
					}
				}
				
				result.success = true;
				result.details = "#fileCount# SQL files cleared";
			} else {
				result.success = true;
				result.details = "No SQL cache directory found";
			}
		} catch (any e) {
			result.details = "Error: #e.message#";
		}
		
		return result;
	}
	
	/**
	 * Format file size in human-readable format
	 */
	private string function formatFileSize(required numeric bytes) {
		var units = ["B", "KB", "MB", "GB"];
		var size = arguments.bytes;
		var unitIndex = 1;
		
		while (size >= 1024 && unitIndex < arrayLen(units)) {
			size = size / 1024;
			unitIndex++;
		}
		
		if (unitIndex == 1) {
			return numberFormat(size, "0") & " " & units[unitIndex];
		} else {
			return numberFormat(size, "0.00") & " " & units[unitIndex];
		}
	}

	/**
	 * Clear server log files
	 */
	private struct function clearLogFiles(required struct serverInfo, required string serverType) {
		var result = {
			cache: "Log Files",
			success: false,
			details: ""
		};
		
		try {
			var logPaths = getServerLogPaths(arguments.serverInfo, arguments.serverType);
			var totalFilesCleared = 0;
			var totalSizeFreed = 0;
			var clearedPaths = [];
			
			for (var logPath in logPaths) {
				if (directoryExists(logPath.path)) {
					print.line("Checking log directory: #logPath.path#");
					
					// Get log files (various extensions)
					var logFiles = directoryList(
						logPath.path, 
						true, 
						"query", 
						"*.log|*.txt|*.out|*.err|*.gc|*.hprof"
					);
					
					var pathFilesCleared = 0;
					var pathSizeFreed = 0;
					
					for (var file in logFiles) {
						if (file.type == "File") {
							try {
								var fileSize = getFileInfo(file.directory & "/" & file.name).size;
								
								// For active log files, truncate instead of delete
								if (isActiveLogFile(file.name)) {
									fileWrite(file.directory & "/" & file.name, "");
									print.line("  Truncated active log: #file.name#");
								} else {
									fileDelete(file.directory & "/" & file.name);
									print.line("  Deleted log: #file.name#");
								}
								
								pathFilesCleared++;
								pathSizeFreed += fileSize;
							} catch (any e) {
								print.yellowLine("  Could not clear #file.name#: #e.message#");
							}
						}
					}
					
					if (pathFilesCleared > 0) {
						clearedPaths.append("#logPath.name#: #pathFilesCleared# files");
						totalFilesCleared += pathFilesCleared;
						totalSizeFreed += pathSizeFreed;
					}
				}
			}
			
			if (totalFilesCleared > 0) {
				result.success = true;
				result.details = "#totalFilesCleared# log files cleared, #formatFileSize(totalSizeFreed)# freed from: #arrayToList(clearedPaths, ', ')#";
			} else {
				result.success = true;
				result.details = "No log files found or accessible";
			}
			
		} catch (any e) {
			result.details = "Error clearing logs: #e.message#";
		}
		
		return result;
	}
	
	/**
	 * Get all possible log file paths for the current server
	 */
	private array function getServerLogPaths(required struct serverInfo, required string serverType) {
		var logPaths = [];
		
		try {
			// Method 1: Get CommandBox server info using system properties
			var commandBoxHome = getCommandBoxHome();
			var currentServerInfo = getCurrentServerInfo();
			
			if (structKeyExists(currentServerInfo, "serverID")) {
				var serverDir = commandBoxHome & "/server/" & currentServerInfo.serverID;
				
				if (arguments.serverType == "lucee") {
					// Lucee log paths
					arrayAppend(logPaths, {
						name: "Lucee Server Logs",
						path: serverDir & "/lucee-6.2.2.91/logs"
					});
					arrayAppend(logPaths, {
						name: "Lucee Web Logs", 
						path: serverDir & "/lucee-6.2.2.91/webroot/WEB-INF/lucee/logs"
					});
				} else {
					// Adobe CF log paths
					arrayAppend(logPaths, {
						name: "ColdFusion Logs",
						path: serverDir & "/cfusion/logs"
					});
				}
				
				// CommandBox server logs
				arrayAppend(logPaths, {
					name: "CommandBox Server Logs",
					path: serverDir & "/logs"
				});
			}
			
			// Method 2: Try to find server directory by scanning CommandBox home
			if (arrayLen(logPaths) == 0) {
				logPaths = scanForServerLogs(commandBoxHome, arguments.serverType);
			}
			
			// Method 3: Fallback to application-level logs
			arrayAppend(logPaths, {
				name: "Application Logs",
				path: fileSystemUtil.resolvePath("logs")
			});
			
		} catch (any e) {
			print.yellowLine("Error detecting server log paths: #e.message#");
			// Fallback to common locations
			arrayAppend(logPaths, {
				name: "Application Logs",
				path: fileSystemUtil.resolvePath("logs")
			});
		}
		
		return logPaths;
	}
	
	/**
	 * Get CommandBox home directory
	 */
	private string function getCommandBoxHome() {
		// Try various methods to get CommandBox home
		var possiblePaths = [
			getSystemProperty("COMMANDBOX_HOME"),
			getSystemProperty("commandbox.home"),
			expandPath("{commandbox-home}"),
			"C:/CommandBox/home",
			"/opt/commandbox/home",
			getUserHome() & "/.CommandBox"
		];
		
		for (var path in possiblePaths) {
			if (len(path) && directoryExists(path)) {
				return path;
			}
		}
		
		// Last resort - try to detect from current working directory
		var cwd = getCurrentDirectory();
		if (findNoCase("CommandBox", cwd)) {
			var parts = listToArray(cwd, "/\");
			for (var i = 1; i <= arrayLen(parts); i++) {
				if (findNoCase("CommandBox", parts[i])) {
					return "/" & arrayToList(arraySlice(parts, 1, i), "/") & "/home";
				}
			}
		}
		
		throw("Could not determine CommandBox home directory");
	}
	
	/**
	 * Get current server information
	 */
	private struct function getCurrentServerInfo() {
		var serverInfo = {};
		
		try {
			// Try to get from system properties set by CommandBox
			var serverID = getSystemProperty("runwar.serverName");
			if (!len(serverID)) {
				serverID = getSystemProperty("server.name");
			}
			
			if (len(serverID)) {
				serverInfo.serverID = serverID;
			} else {
				// Try to get from CGI variables or server scope
				if (structKeyExists(cgi, "server_name")) {
					serverInfo.serverID = hash(cgi.server_name & cgi.server_port, "MD5");
				}
			}
			
		} catch (any e) {
			// Could not determine server info
		}
		
		return serverInfo;
	}
	
	/**
	 * Scan CommandBox home for server directories and logs
	 */
	private array function scanForServerLogs(required string commandBoxHome, required string serverType) {
		var logPaths = [];
		
		try {
			var serverDir = arguments.commandBoxHome & "/server";
			
			if (directoryExists(serverDir)) {
				var serverDirs = directoryList(serverDir, false, "query", "*");
				
				// Look for the most recently modified server directory 
				// (likely the current one)
				var newestDir = "";
				var newestDate = createDateTime(1900, 1, 1, 0, 0, 0);
				
				for (var dir in serverDirs) {
					if (dir.type == "Dir" && dir.dateLastModified > newestDate) {
						newestDate = dir.dateLastModified;
						newestDir = dir.directory & "/" & dir.name;
					}
				}
				
				if (len(newestDir)) {
					print.line("Using most recent server directory: #newestDir#");
					
					if (arguments.serverType == "lucee") {
						// Check for Lucee version directories
						var luceeVersionDirs = directoryList(newestDir, false, "name", "lucee-*");
						for (var versionDir in luceeVersionDirs) {
							arrayAppend(logPaths, {
								name: "Lucee Server Logs",
								path: newestDir & "/" & versionDir & "/logs"
							});
						}
					} else {
						arrayAppend(logPaths, {
							name: "ColdFusion Logs",
							path: newestDir & "/cfusion/logs"
						});
					}
					
					arrayAppend(logPaths, {
						name: "Server Logs",
						path: newestDir & "/logs"
					});
				}
			}
			
		} catch (any e) {
			print.yellowLine("Error scanning for server logs: #e.message#");
		}
		
		return logPaths;
	}
	
	/**
	 * Check if a log file is currently active (should be truncated, not deleted)
	 */
	private boolean function isActiveLogFile(required string filename) {
		var activePatterns = [
			"server.out.txt",
			"server.err.txt", 
			"application.log",
			"exception.log",
			"cfserver.log",
			"lucee.log"
		];
		
		var filename = lcase(arguments.filename);
		
		for (var pattern in activePatterns) {
			if (findNoCase(pattern, filename)) {
				return true;
			}
		}
		
		return false;
	}
	
	/**
	 * Get system property with fallback
	 */
	private string function getSystemProperty(required string key) {
		try {
			var value = createObject("java", "java.lang.System").getProperty(arguments.key);
			return isNull(value) ? "" : value;
		} catch (any e) {
			return "";
		}
	}
	
	/**
	 * Get user home directory
	 */
	private string function getUserHome() {
		try {
			return getSystemProperty("user.home");
		} catch (any e) {
			return "";
		}
	}
	
	/**
	 * Get current working directory
	 */
	private string function getCurrentDirectory() {
		try {
			return getSystemProperty("user.dir");
		} catch (any e) {
			return expandPath("./");
		}
	}
	
	
}