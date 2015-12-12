/*
 * Main.vala
 *
 * Copyright 2015 Tony George <teejee2008@gmail.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
 * MA 02110-1301, USA.
 *
 *
 */

using GLib;
using Gtk;
using Gee;
using Json;

using TeeJee.Logging;
using TeeJee.FileSystem;
using TeeJee.JSON;
using TeeJee.ProcessManagement;
using TeeJee.GtkHelper;
using TeeJee.Multimedia;
using TeeJee.System;
using TeeJee.Misc;

public Main App;
public const string AppName = "Aptik Battery Monitor";
public const string AppShortName = "aptik-battery-monitor";
public const string AppVersion = "2.0";
public const string AppAuthor = "Tony George";
public const string AppAuthorEmail = "teejeetech@gmail.com";

const string GETTEXT_PACKAGE = "";
const string LOCALE_DIR = "/usr/share/locale";

extern void exit(int exit_code);

public class Main : GLib.Object {
	public static string BATT_STATS_CACHE_FILE = "/var/log/aptik-battery-monitor/stats.log";
	public static string BATT_STATS_HIST_FILE = "/var/log/aptik-battery-monitor/history.log";
	
	public static string CMD_MONITOR = "/usr/bin/aptik-battery-monitor &";
	public static string CMD_MONITOR_CRON = "@reboot /usr/bin/aptik-battery-monitor &";

	public static string CMD_BAR = "/usr/bin/aptik-battery-bar &";
	public static string CMD_BAR_CRON = "@reboot sleep 20s && /usr/bin/aptik-battery-bar";
	
	public static int BATT_STATS_LOG_INTERVAL = 30;
	public static double BATT_STATS_ARCHIVE_LEVEL = 99.00;

	public bool gui_mode = false;
	public string user_login = "";
	public string user_home = "";
	public int user_uid = -1;

	public bool print_stats = false;
	public string command = "";
	
	public string temp_dir = "";
	public string backup_dir = "";
	public string share_dir = "/usr/share";
	public string app_conf_path = "";

	public Gee.ArrayList<BatteryStat> battery_stats_list;
	public BatteryStat stat_current;
	public BatteryStat stat_prev;
	public BatteryStat stat_prev2;

	public Main(string[] args, bool _gui_mode) {

		gui_mode = _gui_mode;

		//config file
		string home = Environment.get_home_dir();
		app_conf_path = home + "/.config/aptik-battery-monitor.json";

		//load settings if GUI mode
		if (gui_mode) {
			load_app_config();
		}

		//check dependencies
		string message;
		if (!check_dependencies(out message)) {
			if (gui_mode) {
				string title = _("Missing Dependencies");
				gtk_messagebox(title, message, null, true);
			}
			exit(0);
		}

		//initialize backup_dir as current directory for CLI mode
		if (!gui_mode) {
			backup_dir = Environment.get_current_dir() + "/";
		}

		try {
			//create temp dir
			temp_dir = get_temp_file_path();

			var f = File.new_for_path(temp_dir);
			if (f.query_exists()) {
				Posix.system("rm -rf %s".printf(temp_dir));
			}
			f.make_directory_with_parents();
		}
		catch (Error e) {
			log_error (e.message);
		}

		//get user info
		user_login = get_user_login();
		user_home = "/home/" + user_login;
		user_uid = get_user_id(user_login);

		//BATT_STATS_CACHE_FILE = "%s/.local/log/aptik-battery-monitor/stats.log".printf(user_home);
	}

	public bool check_dependencies(out string msg) {
		msg = "";

		string[] dependencies = { "grep", "find" };

		string path;
		foreach(string cmd_tool in dependencies) {
			path = get_cmd_path (cmd_tool);
			if ((path == null) || (path.length == 0)) {
				msg += " * " + cmd_tool + "\n";
			}
		}

		if (msg.length > 0) {
			msg = _("Commands listed below are not available on this system") + ":\n\n" + msg + "\n";
			msg += _("Please install required packages and try running Aptik again");
			log_msg(msg);
			return false;
		}
		else {
			return true;
		}
	}

	/* Common */

	public string create_log_dir() {
		string log_dir = backup_dir + "logs/" + timestamp3();
		create_dir(log_dir);
		return log_dir;
	}

	public void save_app_config() {
		var config = new Json.Object();

		var json = new Json.Generator();
		json.pretty = true;
		json.indent = 2;
		var node = new Json.Node(NodeType.OBJECT);
		node.set_object(config);
		json.set_root(node);

		try {
			json.to_file(this.app_conf_path);
		} catch (Error e) {
			log_error (e.message);
		}

		if (gui_mode) {
			log_msg(_("App config saved") + ": '%s'".printf(app_conf_path));
		}
	}

	public void load_app_config() {
		var f = File.new_for_path(app_conf_path);
		if (!f.query_exists()) {
			return;
		}

		var parser = new Json.Parser();
		try {
			parser.load_from_file(this.app_conf_path);
		}
		catch (Error e) {
			log_error (e.message);
		}

		//var node = parser.get_root();
		//var config = node.get_object();

		if (gui_mode) {
			log_msg(_("App config loaded") + ": '%s'".printf(this.app_conf_path));
		}
	}

	public void exit_app() {

		save_app_config();

		try {
			//delete temporary files
			var f = File.new_for_path(temp_dir);
			if (f.query_exists()) {
				f.delete();
			}
		}
		catch (Error e) {
			log_error (e.message);
		}
	}

	/* Battery Stats */

	public void log_battery_stats(bool print_stats) {
		try {
			// get stats ----------------------
			
			var stat = new BatteryStat.read_from_sys();
			stat_current = stat;
			
			//create or open log
			var file = File.new_for_path(BATT_STATS_CACHE_FILE);
			if (!file.query_exists()) {
				create_empty_log_file(BATT_STATS_CACHE_FILE);
				battery_stats_list.clear();
			}

			//check if log needs rotation
			check_and_rotate_log();

			//add entry to log
			battery_stats_list.add(stat);
			var fos = file.append_to (FileCreateFlags.NONE);
			var dos = new DataOutputStream (fos);
			dos.put_string(stat.to_delimited_string());
			if (print_stats) {
				stdout.printf(stat.to_friendly_string());
			}

			//rotate references
			stat_prev2 = stat_prev;
			stat_prev = stat_current;
		}
		catch (Error e) {
			log_error (e.message);
		}
	}

	public bool check_and_rotate_log(){
		// rotates log file when battery drops after removing from charger
		
		bool rotated = false;
		
		if ((stat_prev != null) && (stat_prev2 != null)) {

			//check if charge levels for [stat_prev2, stat_prev, stat] are like
			//[ 79.80,  80.00, 79.50] - increase and then decrease, or like
			//[100.00, 100.00, 99.70] - same values and then decrease
	
			if((stat_current.charge_percent() < stat_prev.charge_percent())
					&& 	(   (stat_prev.charge_percent() > stat_prev2.charge_percent())
							|| (stat_prev2.charge_percent() == stat_prev.charge_percent())
						))
			{

				if (print_stats) {
					stdout.printf("\n[Removed from charger]\n\n");
				}
				
				log_battery_cycle_summary();
				
				// create or open log ------------
				var file = File.new_for_path(BATT_STATS_CACHE_FILE);
				if (!file.query_exists()) {
					create_empty_log_file(BATT_STATS_CACHE_FILE);
					battery_stats_list.clear();
				}
				var date_label = (new DateTime.now_local()).format("%F_%H-%M-%S");
				var archive = File.new_for_path(BATT_STATS_CACHE_FILE + "." + date_label);
					
				try{
					file.move(archive, FileCopyFlags.NONE);
					create_empty_log_file(BATT_STATS_CACHE_FILE);
					rotated = true;
				}
				catch(Error e){
					log_error (e.message);
				}
				
				if (print_stats) {
					stdout.printf("Archived: '%s'\n".printf(archive.get_path()));
					stdout.printf("Logging stats to file: '%s'\n\n".printf(BATT_STATS_CACHE_FILE));
				}
			}

			if ((stat_current.charge_percent() > stat_prev.charge_percent())
				&& (stat_prev.charge_percent() < stat_prev2.charge_percent()))
			{
				if (print_stats) {
					stdout.printf("\n[Charging]\n\n");
				}
			}
		}

		return rotated;
	}

	public void log_battery_cycle_summary(){
		try {
			//create or open hist log
			var file = File.new_for_path(BATT_STATS_HIST_FILE);
			if (!file.query_exists()) {
				create_empty_log_file(BATT_STATS_HIST_FILE);
			}

			var cycle = new BatteryCycle();
			cycle.calculate_stats(App.battery_stats_list);
			
			//log cycle summary
			var fos = file.append_to (FileCreateFlags.NONE);
			var dos = new DataOutputStream (fos);
			dos.put_string(cycle.to_delimited_string());
			if (print_stats) {
				stdout.printf("Logging summary to file: '%s'\n".printf(BATT_STATS_HIST_FILE));
				stdout.printf(cycle.to_friendly_string() + "\n");
			}
		}
		catch (Error e) {
			log_error (e.message);
		}
	}
	
	private void create_empty_log_file(string file_path) {
		try {
			var file = File.new_for_path(file_path);
			var parent_dir = file.get_parent();

			if (!parent_dir.query_exists()) {
				parent_dir.make_directory_with_parents();
				Posix.system("chmod a+rwx '%s'".printf(parent_dir.get_path()));
			}

			if (!file.query_exists()) {
				Posix.system("touch '%s'".printf(file.get_path()));
				Posix.system("chmod a+rwx '%s'".printf(file.get_path()));
			}
		}
		catch (Error e) {
			log_error (e.message);
		}
	}

	public void read_battery_stats() {
		log_debug("call: read_battery_stats");
		var timer = timer_start();

		try {
			battery_stats_list = new Gee.ArrayList<BatteryStat>();

			var file = File.new_for_path (BATT_STATS_CACHE_FILE);
			if (file.query_exists ()) {
				var dis = new DataInputStream (file.read());

				string line;
				while ((line = dis.read_line (null)) != null) {
					var stat = new BatteryStat.from_delimited_string(line);
					battery_stats_list.add(stat);

					//stat_current = stat;
					//check_and_rotate_log(false);
					
					// update references
					//stat_prev2 = stat_prev;
					//stat_prev = stat;
				}

				
				if (battery_stats_list.size >= 1){
					stat_current = battery_stats_list[battery_stats_list.size - 1];
				}
				if (battery_stats_list.size >= 2){
					stat_prev = battery_stats_list[battery_stats_list.size - 2];
				}
				if (battery_stats_list.size >= 3){
					stat_prev2 = battery_stats_list[battery_stats_list.size - 3];
				}
				
				log_debug("read_battery_stats: %s".printf(timer_elapsed_string(timer)));
			}
			else {
				log_error ("File not found: %s".printf(BATT_STATS_CACHE_FILE));
			}
		}
		catch (Error e) {
			log_error (e.message);
		}
	}

	public void print_log_file(){
		BatteryStat stat_last = null;
		foreach (BatteryStat stat in App.battery_stats_list){
			if ((stat_last != null)
				&& (stat_last.date.add_seconds(Main.BATT_STATS_LOG_INTERVAL + 1).compare(stat.date) < 0))
			{
				stdout.printf(string.nfill(79, '-') + "\n");
				
				var diff = stat.date.difference(stat_last.date);
				
				var hr = (int64) (diff / (1000000.0 * 60 * 60));
				diff = (int64) (diff % (1000000.0 * 60 * 60));
				var min = (int64) (diff / (1000000.0 * 60));
				diff = (int64) (diff % (1000000.0 * 60));
				var sec = (int64) (diff / (1000000.0));

				stdout.printf("Gap: %02lld:%02lld:%02lld\n".printf(hr,min,sec));
				stdout.printf(string.nfill(79, '-') + "\n");
			}
			
			stdout.printf(stat.to_friendly_string());
			stat_last = stat;
		}
	}

	public bool is_logging_enabled() {
		return (crontab_search(CMD_MONITOR_CRON).length > 0);
	}

	public void set_battery_monitoring_status_cron(bool enabled) {
		string proc_name = "aptik-battery-monitor";
		string command = "nohup /usr/bin/%s".printf(proc_name);
		
		if (enabled) {
			if (!is_logging_enabled()){
				crontab_add(CMD_MONITOR_CRON);
				log_msg("Added crontab entry for '%s'".printf(proc_name));
			}
			else{
				log_msg("Crontab entry exists for '%s'".printf(proc_name));
			}
			
			if (!process_is_running_by_name(proc_name)) {
				execute_command_script_async(command);
				log_msg("Started '%s'".printf(proc_name));
			}
			else{
				log_msg("'%s' is running".printf(proc_name));
			}
		}
		else {
			if (is_logging_enabled()){
				crontab_remove(proc_name); //user short name as search string for removal
				log_msg("Removed crontab entry for '%s'".printf(proc_name));
			}
			else{
				log_msg("Crontab entry does not exist for '%s'".printf(proc_name));
			}

			if (process_is_running_by_name(proc_name)) {
				command_kill(proc_name, proc_name, true);
				log_msg("Killed process '%s'".printf(proc_name));
			}
			else{
				log_msg("'%s' is not running".printf(proc_name));
			}
		}
	}

	public bool is_battery_bar_enabled() {
		return (crontab_search(CMD_BAR_CRON).length > 0);
	}
	
	public void set_battery_bar_status_cron(bool enabled) {
		string proc_name = "aptik-battery-bar";
		string command = "nohup /usr/bin/%s".printf(proc_name);
		
		if (enabled) {
			if (!is_battery_bar_enabled()){
				crontab_add(CMD_BAR_CRON);
				log_msg("Added crontab entry for '%s'".printf(proc_name));
			}
			else{
				log_msg("Crontab entry exists for '%s'".printf(proc_name));
			}
			
			if (!process_is_running_by_name(proc_name)) {
				execute_command_script_async(command);
				log_msg("Started '%s'".printf(proc_name));
			}
			else{
				log_msg("'%s' is running".printf(proc_name));
			}
		}
		else {
			if (is_logging_enabled()){
				crontab_remove(proc_name); //user short name as search string for removal
				log_msg("Removed crontab entry for '%s'".printf(proc_name));
			}
			else{
				log_msg("Crontab entry does not exist for '%s'".printf(proc_name));
			}

			if (process_is_running_by_name(proc_name)) {
				command_kill(proc_name, proc_name, true);
				log_msg("Killed process '%s'".printf(proc_name));
			}
			else{
				log_msg("'%s' is not running".printf(proc_name));
			}
		}
	}
}

