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

	public bool print_stats = false;

	public static int main (string[] args) {
		set_locale();

		LOG_TIMESTAMP = false;

		if (!user_is_admin()){
			string msg = _("Aptik Battery Monitor needs admin access to function correctly.") + "\n";
			msg += _("Please run the application as admin ('sudo aptik-bmon')");
			log_msg(msg);
			exit(0);
		}

		init_tmp();

		App = new Main(args,false);

		var console =  new AptikBatteryStats();
		bool is_success = console.parse_arguments(args);

		App.exit_app();

		return (is_success) ? 0 : 1;
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
		msg += "  --print    " + _("Print stats to standard output") + "\n";
		msg += "  --h[elp]   " + _("Show all options") + "\n";
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
					print_stats = true;
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

		while(true){
			App.log_battery_stats(print_stats);
			sleep(Main.BATT_STATS_LOG_INTERVAL * 1000);
		}

		return true;
	}
}
