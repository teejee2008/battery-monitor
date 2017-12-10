/*
 * BatteryCycle.vala
 *
 * Copyright 2012-2017 Tony George <teejeetech@gmail.com>
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

public class BatteryCycle : GLib.Object{
	
	public DateTime date;
	public double total_drop = 0.0;
	public double total_mins = 0.0;
	public double drop_per_min = 0.0;
	public double average_battery_life_in_mins = 0.0;
	public double remaining_mins = 0.0;
	
	public BatteryCycle(){

	}
	
	public void calculate_stats(Gee.ArrayList<BatteryStat> list){
		BatteryStat stat_last = null;
		total_drop = 0.0;
		total_mins = 0.0;
		drop_per_min = 0.0;
		foreach(BatteryStat stat in list){
			if ((stat_last != null)
				&& (stat.charge_percent() < stat_last.charge_percent())
				&& (stat_last.date.add_seconds(Main.BATT_STATS_LOG_INTERVAL + 1).compare(stat.date) > 0))
			{
				total_drop += (stat_last.charge_percent() - stat.charge_percent());
				total_mins += 0.5;
			}
			stat_last = stat;
			
		}

		if (stat_last != null){
			date = stat_last.date;
		}
		
		if (total_mins > 0){
			drop_per_min = (total_drop / total_mins);
		}

		if (drop_per_min > 0){
			average_battery_life_in_mins = (100.0 / drop_per_min);

			if (stat_last != null){
				remaining_mins = (stat_last.charge_percent() / drop_per_min);
			}
		}
	}

	public string to_delimited_string(){
		var txt = date.to_utc().to_unix().to_string() + "|";
		txt += "%.0f|".printf(total_drop * 1000);
		txt += "%.0f\n".printf(total_mins * 1000);
		return txt;
	}

	public string to_friendly_string(){
		var txt = "";
		txt += date.format("%F %H:%M:%S");
		txt += ", Used %0.2f %% in %.0fh %.0fm @ %0.1f %% per hour".printf(
			total_drop,
			(total_mins / 60.0),
			(total_mins % 60.0),
			(drop_per_min * 60.0)
		);
		txt += "\n";
		return txt;
	}

	public string used_string(){
		return "%0.2f %% in %.0fh %.0fm @ %0.1f %% per hour".printf(
			total_drop,
			(total_mins / 60.0),
			(total_mins % 60.0),
			(drop_per_min * 60.0)
		);
	}

	public string battery_life_string(){
		return "%.0fh %.0fm".printf(average_battery_life_in_mins / 60, average_battery_life_in_mins % 60);
	}

	public string remaining_time_string(){
		return "%.0fh %.0fm".printf(remaining_mins / 60, remaining_mins % 60);
	}

	public static string mins_to_string(double mins){
		return "%.0fh %.0fm".printf(mins / 60, mins % 60);
	}
}


