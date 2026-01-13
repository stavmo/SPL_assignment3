package bgu.spl.net.impl.data;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.io.PrintWriter;
import java.net.Socket;
import java.util.concurrent.ConcurrentHashMap;

public class Database {
	private final ConcurrentHashMap<String, User> userMap;
	private final ConcurrentHashMap<Integer, User> connectionsIdMap;
	private final String sqlHost;
	private final int sqlPort;

	private Database() {
		userMap = new ConcurrentHashMap<>();
		connectionsIdMap = new ConcurrentHashMap<>();
		// SQL server connection details
		this.sqlHost = "127.0.0.1";
		this.sqlPort = 7778;
	}

	public static Database getInstance() {
		return Instance.instance;
	}

	/**
	 * Execute SQL query and return result
	 * @param sql SQL query string
	 * @return Result string from SQL server
	 */
	private String executeSQL(String sql) {
		try (Socket socket = new Socket(sqlHost, sqlPort);
			 PrintWriter out = new PrintWriter(socket.getOutputStream(), true);
			 BufferedReader in = new BufferedReader(new InputStreamReader(socket.getInputStream()))) {
			
			// Send SQL with null terminator
			out.print(sql + '\0');
			out.flush();
			
			// Read response until null terminator
			StringBuilder response = new StringBuilder();
			int ch;
			while ((ch = in.read()) != -1 && ch != '\0') {
				response.append((char) ch);
			}
			
			return response.toString();
			
		} catch (Exception e) {
			System.err.println("SQL Error: " + e.getMessage());
			return "ERROR:" + e.getMessage();
		}
	}

	/**
	 * Escape SQL special characters to prevent SQL injection
	 */
	private String escapeSql(String str) {
		if (str == null) return "";
		return str.replace("'", "''");
	}

	public void addUser(User user) {
		userMap.putIfAbsent(user.name, user);
		connectionsIdMap.putIfAbsent(user.getConnectionId(), user);
	}

	public LoginStatus login(int connectionId, String username, String password) {
		if (connectionsIdMap.containsKey(connectionId)) {
			return LoginStatus.CLIENT_ALREADY_CONNECTED;
		}
		if (addNewUserCase(connectionId, username, password)) {
			// Log new user registration in SQL
			String sql = String.format(
				"INSERT INTO users (username, password, registration_date) VALUES ('%s', '%s', datetime('now'))",
				escapeSql(username), escapeSql(password)
			);
			executeSQL(sql);
			
			// Log login
			logLogin(username);
			return LoginStatus.ADDED_NEW_USER;
		} else {
			LoginStatus status = userExistsCase(connectionId, username, password);
			if (status == LoginStatus.LOGGED_IN_SUCCESSFULLY) {
				// Log successful login in SQL
				logLogin(username);
			}
			return status;
		}
	}

	private void logLogin(String username) {
		String sql = String.format(
			"INSERT INTO login_history (username, login_time) VALUES ('%s', datetime('now'))",
			escapeSql(username)
		);
		executeSQL(sql);
	}

	private LoginStatus userExistsCase(int connectionId, String username, String password) {
		User user = userMap.get(username);
		synchronized (user) {
			if (user.isLoggedIn()) {
				return LoginStatus.ALREADY_LOGGED_IN;
			} else if (!user.password.equals(password)) {
				return LoginStatus.WRONG_PASSWORD;
			} else {
				user.login();
				user.setConnectionId(connectionId);
				connectionsIdMap.put(connectionId, user);
				return LoginStatus.LOGGED_IN_SUCCESSFULLY;
			}
		}
	}

	private boolean addNewUserCase(int connectionId, String username, String password) {
		if (!userMap.containsKey(username)) {
			synchronized (userMap) {
				if (!userMap.containsKey(username)) {
					User user = new User(connectionId, username, password);
					user.login();
					addUser(user);
					return true;
				}
			}
		}
		return false;
	}

	public void logout(int connectionsId) {
		User user = connectionsIdMap.get(connectionsId);
		if (user != null) {
			// Log logout in SQL
			String sql = String.format(
				"UPDATE login_history SET logout_time=datetime('now') " +
				"WHERE username='%s' AND logout_time IS NULL " +
				"ORDER BY login_time DESC LIMIT 1",
				escapeSql(user.name)
			);
			executeSQL(sql);
			
			user.logout();
			connectionsIdMap.remove(connectionsId);
		}
	}

	/**
	 * Track file upload in SQL database
	 * @param username User who uploaded the file
	 * @param filename Name of the file
	 * @param gameChannel Game channel the file was reported to
	 */
	public void trackFileUpload(String username, String filename, String gameChannel) {
		String sql = String.format(
			"INSERT INTO file_tracking (username, filename, upload_time, game_channel) " +
			"VALUES ('%s', '%s', datetime('now'), '%s')",
			escapeSql(username), escapeSql(filename), escapeSql(gameChannel)
		);
		executeSQL(sql);
	}

	/**
	 * Generate and print server report using SQL queries
	 */
	public void printReport() {
		System.out.println(repeat("=", 80));
		System.out.println("SERVER REPORT - Generated at: " + java.time.LocalDateTime.now());
		System.out.println(repeat("=", 80));
		
		// List all users
		System.out.println("\n1. REGISTERED USERS:");
		System.out.println(repeat("-", 80));
		String usersSQL = "SELECT username, registration_date FROM users ORDER BY registration_date";
		String usersResult = executeSQL(usersSQL);
		if (usersResult.startsWith("SUCCESS")) {
			String[] parts = usersResult.split("\\|");
			if (parts.length > 1) {
				for (int i = 1; i < parts.length; i++) {
					System.out.println("   " + parts[i]);
				}
			} else {
				System.out.println("   No users registered");
			}
		}
		
		// Login history for each user
		System.out.println("\n2. LOGIN HISTORY:");
		System.out.println(repeat("-", 80));
		String loginSQL = "SELECT username, login_time, logout_time FROM login_history ORDER BY username, login_time DESC";
		String loginResult = executeSQL(loginSQL);
		if (loginResult.startsWith("SUCCESS")) {
			String[] parts = loginResult.split("\\|");
			if (parts.length > 1) {
				String currentUser = "";
				for (int i = 1; i < parts.length; i++) {
					String[] fields = parts[i].replace("(", "").replace(")", "").replace("'", "").split(", ");
					if (fields.length >= 3) {
						if (!fields[0].equals(currentUser)) {
							currentUser = fields[0];
							System.out.println("\n   User: " + currentUser);
						}
						System.out.println("      Login:  " + fields[1]);
						System.out.println("      Logout: " + (fields[2].equals("None") ? "Still logged in" : fields[2]));
					}
				}
			} else {
				System.out.println("   No login history");
			}
		}
		
		// File uploads for each user
		System.out.println("\n3. FILE UPLOADS:");
		System.out.println(repeat("-", 80));
		String filesSQL = "SELECT username, filename, upload_time, game_channel FROM file_tracking ORDER BY username, upload_time DESC";
		String filesResult = executeSQL(filesSQL);
		if (filesResult.startsWith("SUCCESS")) {
			String[] parts = filesResult.split("\\|");
			if (parts.length > 1) {
				String currentUser = "";
				for (int i = 1; i < parts.length; i++) {
					String[] fields = parts[i].replace("(", "").replace(")", "").replace("'", "").split(", ");
					if (fields.length >= 4) {
						if (!fields[0].equals(currentUser)) {
							currentUser = fields[0];
							System.out.println("\n   User: " + currentUser);
						}
						System.out.println("      File: " + fields[1]);
						System.out.println("      Time: " + fields[2]);
						System.out.println("      Game: " + fields[3]);
						System.out.println();
					}
				}
			} else {
				System.out.println("   No files uploaded");
			}
		}
		
	System.out.println(repeat("=", 80));
}

private String repeat(String str, int times) {
	StringBuilder sb = new StringBuilder();
	for (int i = 0; i < times; i++) {
		sb.append(str);
	}
	return sb.toString();
}

private static class Instance {
	static Database instance = new Database();
}}