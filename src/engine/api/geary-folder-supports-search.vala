/*
 * Copyright © 2026 Christopher Harrison
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later). See the COPYING file in this distribution.
 */

/** Supported server-side flag filters. */
public enum Geary.FolderSupport.FlagFilter {
    UNREAD,
    STARRED
}

/** Indicates a folder supports server-side flag searches. */
public interface Geary.FolderSupport.Search : Geary.Folder {

    /**
     * Returns every message matching the given flag filter.
     *
     * The folder must be opened before this method is called. Returned
     * messages fulfill all requested fields.
     */
    public abstract async Gee.Collection<Email> search_flag_async(
        FlagFilter filter,
        Email.Field required_fields,
        GLib.Cancellable? cancellable = null
    ) throws GLib.Error;

}
