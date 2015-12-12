/*
 * AptikBatteryStats.vala
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
using Soup;
using Json;

using TeeJee.Logging;
using TeeJee.FileSystem;
using TeeJee.JSON;
using TeeJee.ProcessManagement;
using TeeJee.GtkHelper;
using TeeJee.Multimedia;
using TeeJee.System;
using TeeJee.Misc;

public class AptikBatteryStats : GLib.Object{
	public static int main (string[] args) {
		set_locale();

		LOG_TIMESTAMP = false;

		init_tmp();

		App = new Main(args,false);
		App.check_for_multiple_instances();
		
		var console =  new AptikBatteryStats();
		console.parse_arguments(args);

		if (App.print_stats){
			stdout.printf(_("Logging stats to file") + ": '%s'\n\n".printf(Main.BATT_STATS_CACHE_FILE));
		}

		App.read_battery_stats();

		if (App.command == "print_log"){
			App.print_log_file();
			exit(0);
		}
		else{
			while(true){
				App.log_battery_stats(App.print_stats);
				sleep(Main.BATT_STATS_LOG_INTERVAL * 1000);
			}
		}

		return 0;
	}

	private static void set_locale(){
		Intl.setlocale(GLib.LocaleCategory.MESSAGES, AppShortName);
		Intl.textdomain(GETTEXT_PACKAGE);
		Intl.bind_textdomain_codeset(GETTEXT_PACKAGE, "utf-8");
		Intl.bindtextdomain(GETTEXT_PACKAGE, LOCALE_DIR);
	}

	public string help_message(){
		string msg = "\n" + AppName + " v" + AppVersion + " by Tony George (teejee2008@gmail.com)" + "\n";
		msg += "\n";
		msg += _("Syntax") + ": " + AppShortName + " [options]\n";
		msg += "\n";
		msg += _("Options") + ":\n";
		msg += "\n";
		msg += "  --print      " + _("Print stats to standard output") + "\n";
		msg += "  --print-log  " + _("Print stats from log file sand quit") + "\n";
		msg += "  --h[elp]     " + _("Show all options") + "\n";
		msg += "\n";
		return msg;
	}

	public bool parse_arguments(string[] args){

		//parse options
		for (int k = 1; k < args.length; k++) // Oth arg is app path
		{
			switch (args[k].down()){
				case "--debug":
					LOG_DEBUG = true;
					break;
				case "--print":
					App.print_stats = true;
					break;
				case "--print-log":
					App.command = "print_log";
					break;
				case "--help":
				case "--h":
				case "-h":
					log_msg(help_message());
					return true;
				default:
					//unknown option - ignore, no errors
					return false;
			}
		}

		return true;
	}
}
