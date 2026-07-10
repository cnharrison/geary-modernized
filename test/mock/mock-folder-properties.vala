/*
 * Copyright 2019 Michael Gratton <mike@vee.net>
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later). See the COPYING file in this distribution.
 */

public class Mock.FolderPoperties : Geary.FolderProperties {


    public FolderPoperties(int email_total = 0, int email_unread = 0) {
        base(
            email_total,
            email_unread,
            Geary.Trillian.UNKNOWN,
            Geary.Trillian.UNKNOWN,
            Geary.Trillian.UNKNOWN,
            false,
            false,
            false
        );
    }

}
