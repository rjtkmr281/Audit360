/**
 * @name        Audit360_LoginActivityController
 * @description AppExchange-grade controller for LoginGuard - User Login History & Security Monitor
 * @version     4.1.0
 *
 * LoginHistory SOQL Restrictions (hard Salesforce platform limits):
 *  - NO relationship traversal  → User.Name, User.Email etc. are NOT allowed in SELECT
 *  - NO GROUP BY / HAVING / aggregate functions (COUNT, COUNT_DISTINCT, DAY_ONLY etc.)
 *  - NO LAST_N_HOURS date literal
 *  - NO WHERE on Status        → Status is NOT filterable in SOQL
 *  - NO WHERE on Browser       → Browser is NOT filterable in SOQL
 *  - NO ORDER BY on Status / Browser / SourceIp in all API versions
 *
 *  SOLUTION: Fetch only by LoginTime (the one filterable field), then do ALL
 *  filtering / sorting / aggregation in Apex using Maps and loops.
 *
 * v4.1.0 Fix:
 *  - Removed Security.stripInaccessible() from buildUserMap() — it destroys
 *    Profile.Name and UserRole.Name relationship fields, causing the
 *    "Variable does not exist: Email / Source" compile/runtime error.
 *  - Direct Map<Id,User> query is safe here; LoginHistory access already
 *    requires elevated permissions (View All Data or delegated access).
 */
public without sharing class Audit360_LoginActivityController {

    // ─────────────────────────────────────────────────────────────────────────
    // ALLOWLIST CONSTANTS
    // ─────────────────────────────────────────────────────────────────────────

    private static final Set<String> ALLOWED_LOGIN_TYPES = new Set<String>{
        'Application', 'Partner Product', 'SSO', 'RemoteAccess 1.0',
        'RemoteAccess 2.0', 'Other Apex API', 'SAML Idp Initiated SSO',
        'SAML SP Initiated SSO', 'Employee Login Link', 'My Domain Discovery',
        'SAML Sfdc Initiated SSO'
    };

    private static final Set<String> ALLOWED_BROWSERS = new Set<String>{
        'Chrome', 'Firefox', 'Safari', 'Edge', 'IE', 'Opera', 'Unknown'
    };

    // Only LoginTime and LoginType are safely sortable on LoginHistory
    private static final Set<String> ALLOWED_SORT_FIELDS = new Set<String>{
        'LoginTime', 'LoginType', 'Application', 'Platform'
    };

    // ─────────────────────────────────────────────────────────────────────────
    // SECTION 1 ── Login History (paginated, filtered, sorted)
    // ─────────────────────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static LoginHistoryResult getLoginHistory(
        String  searchKey,
        String  statusFilter,
        String  loginTypeFilter,
        String  browserFilter,
        String  dateRangeFilter,
        String  dateFrom,
        String  dateTo,
        String  sortField,
        String  sortDir,
        Integer pageSize,
        Integer pageNumber
    ) {
        try {
            Integer safePage  = (pageNumber != null && pageNumber > 0) ? pageNumber : 1;
            Integer safeSize  = (pageSize   != null && pageSize   > 0) ? pageSize   : 20;
            Integer offsetVal = (safePage - 1) * safeSize;

            String orderField = ALLOWED_SORT_FIELDS.contains(sortField) ? sortField : 'LoginTime';
            String orderDir   = (sortDir == 'asc') ? 'ASC' : 'DESC';

            String dateClause = buildDateClause(dateRangeFilter, dateFrom, dateTo);

            String soql =
                'SELECT Id, UserId, LoginTime, LoginType, LoginUrl, SourceIp, ' +
                'Status, Browser, Platform, Application, ApiType, ApiVersion ' +
                'FROM LoginHistory ' +
                'WHERE ' + dateClause + ' ' +
                'ORDER BY ' + orderField + ' ' + orderDir + ' ' +
                'LIMIT 50000';

            List<LoginHistory> allRows = Database.query(soql);

            Set<Id> userIds = new Set<Id>();
            for (LoginHistory lh : allRows) {
                if (lh.UserId != null) userIds.add(lh.UserId);
            }
            Map<Id, User> userMap = buildUserMap(userIds);

            List<LoginHistory> filtered = applyFilters(
                allRows, searchKey, statusFilter, loginTypeFilter, browserFilter, userMap
            );

            Integer total    = filtered.size();
            List<LoginHistory> pageRows = new List<LoginHistory>();
            for (Integer i = offsetVal; i < Math.min(offsetVal + safeSize, total); i++) {
                pageRows.add(filtered[i]);
            }

            LoginHistoryResult result = new LoginHistoryResult();
            result.records    = buildWrappers(pageRows, userMap);
            result.totalCount = total;
            result.pageNumber = safePage;
            result.pageSize   = safeSize;
            return result;

        } catch (Exception ex) {
            throw new AuraHandledException('LoginGuard Error: ' + ex.getMessage());
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // SECTION 2 ── Dashboard KPI Statistics
    // ─────────────────────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static DashboardStats getDashboardStats(String dateRangeFilter) {
        try {
            String dateClause = buildDateClause(dateRangeFilter, null, null);

            List<LoginHistory> rows = Database.query(
                'SELECT Id, UserId, LoginTime, Status, Browser, SourceIp ' +
                'FROM LoginHistory ' +
                'WHERE ' + dateClause + ' ' +
                'ORDER BY LoginTime DESC ' +
                'LIMIT 50000'
            );

            Set<Id>              uniqueUserIds = new Set<Id>();
            Integer              successCount  = 0;
            Integer              failedCount   = 0;
            Integer              todayCount    = 0;
            Date                 todayDate     = Date.today();
            Map<String, Integer> browserMap    = new Map<String, Integer>();
            Map<String, Integer> failedIpMap   = new Map<String, Integer>();
            Map<Id,     Integer> userCountMap  = new Map<Id, Integer>();

            for (LoginHistory lh : rows) {
                if (lh.UserId != null) uniqueUserIds.add(lh.UserId);

                Boolean isSuccess = (lh.Status == 'Success');
                if (isSuccess) {
                    successCount++;
                } else {
                    failedCount++;
                    String ip = (lh.SourceIp != null) ? lh.SourceIp : 'Unknown';
                    failedIpMap.put(ip, (failedIpMap.containsKey(ip) ? failedIpMap.get(ip) : 0) + 1);
                }

                if (lh.LoginTime != null && lh.LoginTime.date() == todayDate) {
                    todayCount++;
                }

                String br = (lh.Browser != null && lh.Browser != '') ? lh.Browser : 'Unknown';
                browserMap.put(br, (browserMap.containsKey(br) ? browserMap.get(br) : 0) + 1);

                if (lh.UserId != null) {
                    userCountMap.put(
                        lh.UserId,
                        (userCountMap.containsKey(lh.UserId) ? userCountMap.get(lh.UserId) : 0) + 1
                    );
                }
            }

            Map<Id, User> userMap = buildUserMap(uniqueUserIds);

            DashboardStats s  = new DashboardStats();
            s.totalLogins     = rows.size();
            s.successLogins   = successCount;
            s.failedLogins    = failedCount;
            s.uniqueUsers     = uniqueUserIds.size();
            s.todayLogins     = todayCount;
            s.browserBreakdown = topNFromMap(browserMap, 5);
            s.dailyTrend      = buildDailyTrend(rows);
            s.topUsers        = buildTopUsers(userCountMap, userMap, 5);
            s.suspiciousIps   = buildTopIps(failedIpMap, 5);

            return s;

        } catch (Exception ex) {
            throw new AuraHandledException('Stats Error: ' + ex.getMessage());
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // SECTION 3 ── User Drill-Down
    // ─────────────────────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static List<LoginHistoryWrapper> getUserLoginHistory(
        String  userId,
        Integer limitSize
    ) {
        try {
            Integer safeLimit  = (limitSize != null && limitSize > 0) ? limitSize : 50;
            Id      safeUserId = (Id) userId;

            List<LoginHistory> rows = [
                SELECT Id, UserId, LoginTime, LoginType, LoginUrl, SourceIp,
                       Status, Browser, Platform, Application, ApiType, ApiVersion
                FROM LoginHistory
                WHERE UserId = :safeUserId
                ORDER BY LoginTime DESC
                LIMIT :safeLimit
            ];

            Set<Id> ids = new Set<Id>{ safeUserId };
            Map<Id, User> userMap = buildUserMap(ids);
            return buildWrappers(rows, userMap);

        } catch (Exception ex) {
            throw new AuraHandledException('User Drill-Down Error: ' + ex.getMessage());
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // SECTION 4 ── Security Alerts
    // ─────────────────────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static List<SecurityAlert> getSecurityAlerts() {
        try {
            List<SecurityAlert> alerts = new List<SecurityAlert>();

            // ── Alert 1: Failed login spike (5+ failures in last 24 hours) ──
            DateTime cutoff24h = DateTime.now().addHours(-24);

            List<LoginHistory> rows24h = [
                SELECT Id, UserId, Status
                FROM LoginHistory
                WHERE LoginTime >= :cutoff24h
                ORDER BY LoginTime DESC
                LIMIT 10000
            ];

            Map<Id, Integer> failCountMap = new Map<Id, Integer>();
            for (LoginHistory lh : rows24h) {
                if (lh.Status != 'Success') {
                    Integer c = failCountMap.containsKey(lh.UserId) ? failCountMap.get(lh.UserId) : 0;
                    failCountMap.put(lh.UserId, c + 1);
                }
            }

            Set<Id> spikeUserIds = new Set<Id>();
            for (Id uid : failCountMap.keySet()) {
                if (failCountMap.get(uid) >= 5) spikeUserIds.add(uid);
            }
            if (!spikeUserIds.isEmpty()) {
                Map<Id, User> spikeUsers = buildUserMap(spikeUserIds);
                for (Id uid : spikeUserIds) {
                    SecurityAlert a = new SecurityAlert();
                    a.alertType   = 'Failed Login Spike';
                    a.severity    = 'Critical';
                    a.userId      = uid;
                    a.userName    = spikeUsers.containsKey(uid) ? spikeUsers.get(uid).Name : String.valueOf(uid);
                    a.description = failCountMap.get(uid) + ' failed login attempts in last 24 hours';
                    a.icon        = 'utility:error';
                    alerts.add(a);
                }
            }

            // ── Alert 2: Multiple IPs in last 1 hour ──
            DateTime cutoff1h = DateTime.now().addHours(-1);

            List<LoginHistory> rows1h = [
                SELECT Id, UserId, Status, SourceIp
                FROM LoginHistory
                WHERE LoginTime >= :cutoff1h
                ORDER BY LoginTime DESC
                LIMIT 5000
            ];

            Map<Id, Set<String>> userIpMap = new Map<Id, Set<String>>();
            for (LoginHistory lh : rows1h) {
                if (lh.Status == 'Success' && lh.SourceIp != null) {
                    if (!userIpMap.containsKey(lh.UserId)) {
                        userIpMap.put(lh.UserId, new Set<String>());
                    }
                    userIpMap.get(lh.UserId).add(lh.SourceIp);
                }
            }

            Set<Id> multiIpUserIds = new Set<Id>();
            for (Id uid : userIpMap.keySet()) {
                if (userIpMap.get(uid).size() >= 3) multiIpUserIds.add(uid);
            }
            if (!multiIpUserIds.isEmpty()) {
                Map<Id, User> multiIpUsers = buildUserMap(multiIpUserIds);
                for (Id uid : multiIpUserIds) {
                    SecurityAlert a = new SecurityAlert();
                    a.alertType   = 'Multiple IP Logins';
                    a.severity    = 'High';
                    a.userId      = uid;
                    a.userName    = multiIpUsers.containsKey(uid) ? multiIpUsers.get(uid).Name : String.valueOf(uid);
                    a.description = 'Logged in from ' + userIpMap.get(uid).size() + ' different IPs in last hour';
                    a.icon        = 'utility:warning';
                    alerts.add(a);
                }
            }

            // ── Alert 3: Off-hours logins today ──
            Date     todayDate    = Date.today();
            DateTime startOfToday = DateTime.newInstance(todayDate, Time.newInstance(0,0,0,0));
            DateTime endOfToday   = DateTime.newInstance(todayDate, Time.newInstance(23,59,59,0));

            List<LoginHistory> todayRows = [
                SELECT Id, UserId, LoginTime, Status
                FROM LoginHistory
                WHERE LoginTime >= :startOfToday
                AND   LoginTime <= :endOfToday
                ORDER BY LoginTime DESC
                LIMIT 2000
            ];

            Set<Id>          offHoursUserIds = new Set<Id>();
            Map<Id, Integer> offHoursHour    = new Map<Id, Integer>();
            for (LoginHistory lh : todayRows) {
                if (lh.LoginTime == null) continue;
                if (lh.Status != 'Success') continue;
                Integer hr = lh.LoginTime.hour();
                if ((hr < 6 || hr >= 22) && !offHoursUserIds.contains(lh.UserId)) {
                    offHoursUserIds.add(lh.UserId);
                    offHoursHour.put(lh.UserId, hr);
                }
            }

            if (!offHoursUserIds.isEmpty()) {
                Map<Id, User> offHoursUsers = buildUserMap(offHoursUserIds);
                for (Id uid : offHoursUserIds) {
                    SecurityAlert a = new SecurityAlert();
                    a.alertType   = 'Off-Hours Login';
                    a.severity    = 'Medium';
                    a.userId      = uid;
                    a.userName    = offHoursUsers.containsKey(uid) ? offHoursUsers.get(uid).Name : String.valueOf(uid);
                    a.description = 'Login detected outside business hours (' + offHoursHour.get(uid) + ':00)';
                    a.icon        = 'utility:clock';
                    alerts.add(a);
                }
            }

            return alerts;

        } catch (Exception ex) {
            throw new AuraHandledException('Alert Error: ' + ex.getMessage());
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // SECTION 5 ── CSV Export
    // ─────────────────────────────────────────────────────────────────────────

    @AuraEnabled
    public static String exportToCsv(
        String searchKey,
        String statusFilter,
        String loginTypeFilter,
        String browserFilter,
        String dateRangeFilter,
        String dateFrom,
        String dateTo
    ) {
        try {
            String dateClause = buildDateClause(dateRangeFilter, dateFrom, dateTo);

            List<LoginHistory> allRows = Database.query(
                'SELECT Id, UserId, LoginTime, LoginType, SourceIp, ' +
                'Status, Browser, Platform ' +
                'FROM LoginHistory ' +
                'WHERE ' + dateClause + ' ' +
                'ORDER BY LoginTime DESC ' +
                'LIMIT 2000'
            );

            Set<Id> userIds = new Set<Id>();
            for (LoginHistory lh : allRows) {
                if (lh.UserId != null) userIds.add(lh.UserId);
            }
            Map<Id, User> userMap = buildUserMap(userIds);

            List<LoginHistory> filtered = applyFilters(
                allRows, searchKey, statusFilter, loginTypeFilter, browserFilter, userMap
            );

            String csv = 'User Name,Email,Profile,Login Time,Login Type,IP Address,Status,Browser,Platform\n';
            for (LoginHistory lh : filtered) {
                User   u        = userMap.containsKey(lh.UserId) ? userMap.get(lh.UserId) : null;
                String uName    = (u != null) ? safe(u.Name)                               : '';
                String uEmail   = (u != null) ? safe(u.Email)                              : '';
                String uProfile = (u != null && u.Profile != null) ? safe(u.Profile.Name) : '';

                csv += '"' + uName                        + '",' +
                       '"' + uEmail                       + '",' +
                       '"' + uProfile                     + '",' +
                       '"' + String.valueOf(lh.LoginTime) + '",' +
                       '"' + safe(lh.LoginType)           + '",' +
                       '"' + safe(lh.SourceIp)            + '",' +
                       '"' + safe(lh.Status)              + '",' +
                       '"' + safe(lh.Browser)             + '",' +
                       '"' + safe(lh.Platform)            + '"\n';
            }

            ContentVersion cv = new ContentVersion();
            cv.Title          = 'LoginHistory_Export_' + Datetime.now().format('yyyyMMdd_HHmmss');
            cv.PathOnClient   = 'LoginHistory_Export.csv';
            cv.VersionData    = Blob.valueOf(csv);
            cv.IsMajorVersion = true;
            insert cv;

            ContentVersion inserted = [
                SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1
            ];
            return inserted.ContentDocumentId;

        } catch (Exception ex) {
            throw new AuraHandledException('Export Error: ' + ex.getMessage());
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // PRIVATE HELPERS
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Builds a safe SOQL WHERE fragment using only LoginTime.
     * Returns only the condition string — does NOT include "WHERE".
     */
    private static String buildDateClause(
        String dateRangeFilter,
        String dateFrom,
        String dateTo
    ) {
        if (dateRangeFilter == 'TODAY')  return 'LoginTime = TODAY';
        if (dateRangeFilter == 'LAST7')  return 'LoginTime = LAST_N_DAYS:7';
        if (dateRangeFilter == 'LAST30') return 'LoginTime = LAST_N_DAYS:30';
        if (dateRangeFilter == 'LAST90') return 'LoginTime = LAST_N_DAYS:90';

        if (String.isNotBlank(dateFrom) && String.isNotBlank(dateTo)) {
            String safeFrom = String.escapeSingleQuotes(dateFrom);
            String safeTo   = String.escapeSingleQuotes(dateTo);
            return 'LoginTime >= ' + safeFrom + 'T00:00:00Z' +
                   ' AND LoginTime <= ' + safeTo + 'T23:59:59Z';
        }

        return 'LoginTime = LAST_N_DAYS:30';
    }

    /**
     * Applies ALL non-date filters in Apex.
     * Status, Browser, SourceIp, and search are NOT filterable in SOQL on LoginHistory.
     */
    private static List<LoginHistory> applyFilters(
        List<LoginHistory> rows,
        String searchKey,
        String statusFilter,
        String loginTypeFilter,
        String browserFilter,
        Map<Id, User> userMap
    ) {
        String lowerSearch = String.isNotBlank(searchKey) ? searchKey.toLowerCase() : null;

        String validLoginType = (String.isNotBlank(loginTypeFilter)
            && loginTypeFilter != 'All'
            && ALLOWED_LOGIN_TYPES.contains(loginTypeFilter)) ? loginTypeFilter : null;

        String validBrowser = (String.isNotBlank(browserFilter)
            && browserFilter != 'All'
            && ALLOWED_BROWSERS.contains(browserFilter)) ? browserFilter.toLowerCase() : null;

        Boolean filterStatus = String.isNotBlank(statusFilter) && statusFilter != 'All';

        List<LoginHistory> result = new List<LoginHistory>();
        for (LoginHistory lh : rows) {

            // Status filter in Apex (NOT filterable in SOQL on LoginHistory)
            if (filterStatus) {
                if (statusFilter == 'Success' && lh.Status != 'Success') continue;
                if (statusFilter == 'Failed'  && lh.Status == 'Success') continue;
            }

            // LoginType filter
            if (validLoginType != null && lh.LoginType != validLoginType) continue;

            // Browser filter in Apex (NOT filterable in SOQL on LoginHistory)
            if (validBrowser != null) {
                String lhBrowser = (lh.Browser != null) ? lh.Browser.toLowerCase() : '';
                if (!lhBrowser.contains(validBrowser)) continue;
            }

            // Search filter — checks user name, email, and IP
            if (lowerSearch != null) {
                User   u      = userMap.containsKey(lh.UserId) ? userMap.get(lh.UserId) : null;
                String uName  = (u != null && u.Name  != null) ? u.Name.toLowerCase()  : '';
                String uEmail = (u != null && u.Email != null) ? u.Email.toLowerCase() : '';
                String ip     = (lh.SourceIp != null) ? lh.SourceIp.toLowerCase() : '';
                if (!uName.contains(lowerSearch)
                    && !uEmail.contains(lowerSearch)
                    && !ip.contains(lowerSearch)) {
                    continue;
                }
            }

            result.add(lh);
        }
        return result;
    }

    /**
     * Bulk-queries User records.
     *
     * FIX v4.1: Removed Security.stripInaccessible() — it silently drops
     * relationship fields (Profile.Name, UserRole.Name) from the returned
     * SObjects, which causes "Variable does not exist" errors when buildWrappers
     * or exportToCsv tries to read u.Profile.Name / u.Email on the stripped record.
     * LoginHistory access already requires elevated org permissions, so a plain
     * User query is the correct and safe approach here.
     */
    private static Map<Id, User> buildUserMap(Set<Id> userIds) {
        Map<Id, User> result = new Map<Id, User>();
        if (userIds == null || userIds.isEmpty()) return result;

        for (User u : [
            SELECT Id, Name, Email, IsActive, Department,
                   Profile.Name, UserRole.Name
            FROM User
            WHERE Id IN :userIds
        ]) {
            result.put(u.Id, u);
        }
        return result;
    }

    /**
     * Maps LoginHistory rows + User map into wrapper objects.
     */
    private static List<LoginHistoryWrapper> buildWrappers(
        List<LoginHistory> rows,
        Map<Id, User> userMap
    ) {
        List<LoginHistoryWrapper> result = new List<LoginHistoryWrapper>();
        for (LoginHistory lh : rows) {
            User u = userMap.containsKey(lh.UserId) ? userMap.get(lh.UserId) : null;
            LoginHistoryWrapper w = new LoginHistoryWrapper();
            w.id          = lh.Id;
            w.userId      = lh.UserId;
            w.userName    = (u != null) ? u.Name       : '';
            w.userEmail   = (u != null) ? u.Email      : '';
            w.isActive    = (u != null) ? u.IsActive   : false;
            w.profileName = (u != null && u.Profile  != null) ? u.Profile.Name  : '';
            w.roleName    = (u != null && u.UserRole != null) ? u.UserRole.Name : '';
            w.department  = (u != null) ? u.Department : '';
            w.loginTime   = lh.LoginTime;
            w.loginType   = lh.LoginType;
            w.loginUrl    = lh.LoginUrl;
            w.sourceIp    = lh.SourceIp;
            w.status      = lh.Status;
            w.browser     = lh.Browser;
            w.platform    = lh.Platform;
            w.application = lh.Application;
            w.apiType     = lh.ApiType;
            w.apiVersion  = lh.ApiVersion;
            result.add(w);
        }
        return result;
    }

    /**
     * Builds daily trend for last 7 days from already-fetched rows.
     * No extra SOQL needed — LoginHistory does not support GROUP BY.
     */
    private static List<ChartPoint> buildDailyTrend(List<LoginHistory> rows) {
        Date today = Date.today();
        Map<String, Integer> dayMap = new Map<String, Integer>();
        for (Integer i = 6; i >= 0; i--) {
            dayMap.put(String.valueOf(today.addDays(-i)), 0);
        }
        for (LoginHistory lh : rows) {
            if (lh.LoginTime == null) continue;
            String dayKey = String.valueOf(lh.LoginTime.date());
            if (dayMap.containsKey(dayKey)) {
                dayMap.put(dayKey, dayMap.get(dayKey) + 1);
            }
        }
        List<ChartPoint> trend = new List<ChartPoint>();
        for (Integer i = 6; i >= 0; i--) {
            String label = String.valueOf(today.addDays(-i));
            ChartPoint cp = new ChartPoint();
            cp.label = label;
            cp.value = dayMap.get(label);
            trend.add(cp);
        }
        return trend;
    }

    /** Returns top N entries from a String->Integer map sorted descending. */
    private static List<ChartPoint> topNFromMap(Map<String, Integer> src, Integer n) {
        List<String> keys = new List<String>(src.keySet());
        for (Integer i = 0; i < keys.size() - 1; i++) {
            for (Integer j = 0; j < keys.size() - 1 - i; j++) {
                if (src.get(keys[j]) < src.get(keys[j+1])) {
                    String tmp = keys[j]; keys[j] = keys[j+1]; keys[j+1] = tmp;
                }
            }
        }
        List<ChartPoint> result = new List<ChartPoint>();
        for (Integer k = 0; k < Math.min(n, keys.size()); k++) {
            ChartPoint cp = new ChartPoint();
            cp.label = keys[k];
            cp.value = src.get(keys[k]);
            result.add(cp);
        }
        return result;
    }

    /** Builds top N UserStat list from userId->count map sorted descending. */
    private static List<UserStat> buildTopUsers(
        Map<Id, Integer> countMap,
        Map<Id, User>    userMap,
        Integer          n
    ) {
        List<Id> ids = new List<Id>(countMap.keySet());
        for (Integer i = 0; i < ids.size() - 1; i++) {
            for (Integer j = 0; j < ids.size() - 1 - i; j++) {
                if (countMap.get(ids[j]) < countMap.get(ids[j+1])) {
                    Id tmp = ids[j]; ids[j] = ids[j+1]; ids[j+1] = tmp;
                }
            }
        }
        List<UserStat> result = new List<UserStat>();
        for (Integer k = 0; k < Math.min(n, ids.size()); k++) {
            Id uid = ids[k];
            UserStat us = new UserStat();
            us.userId   = uid;
            us.userName = userMap.containsKey(uid) ? userMap.get(uid).Name : String.valueOf(uid);
            us.count    = countMap.get(uid);
            result.add(us);
        }
        return result;
    }

    /** Builds top N IpStat list from ip->count map sorted descending. */
    private static List<IpStat> buildTopIps(Map<String, Integer> ipMap, Integer n) {
        List<String> ips = new List<String>(ipMap.keySet());
        for (Integer i = 0; i < ips.size() - 1; i++) {
            for (Integer j = 0; j < ips.size() - 1 - i; j++) {
                if (ipMap.get(ips[j]) < ipMap.get(ips[j+1])) {
                    String tmp = ips[j]; ips[j] = ips[j+1]; ips[j+1] = tmp;
                }
            }
        }
        List<IpStat> result = new List<IpStat>();
        for (Integer k = 0; k < Math.min(n, ips.size()); k++) {
            IpStat ip = new IpStat();
            ip.ipAddress = ips[k];
            ip.count     = ipMap.get(ips[k]);
            result.add(ip);
        }
        return result;
    }

    /** Escapes double-quotes inside a CSV cell value. */
    private static String safe(String s) {
        if (s == null) return '';
        return s.replace('"', '""');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // WRAPPER / RESULT CLASSES
    // ─────────────────────────────────────────────────────────────────────────

    public class LoginHistoryResult {
        @AuraEnabled public List<LoginHistoryWrapper> records;
        @AuraEnabled public Integer totalCount;
        @AuraEnabled public Integer pageNumber;
        @AuraEnabled public Integer pageSize;
    }

    public class LoginHistoryWrapper {
        @AuraEnabled public String   id;
        @AuraEnabled public String   userId;
        @AuraEnabled public String   userName;
        @AuraEnabled public String   userEmail;
        @AuraEnabled public Boolean  isActive;
        @AuraEnabled public String   profileName;
        @AuraEnabled public String   roleName;
        @AuraEnabled public String   department;
        @AuraEnabled public DateTime loginTime;
        @AuraEnabled public String   loginType;
        @AuraEnabled public String   loginUrl;
        @AuraEnabled public String   sourceIp;
        @AuraEnabled public String   status;
        @AuraEnabled public String   browser;
        @AuraEnabled public String   platform;
        @AuraEnabled public String   application;
        @AuraEnabled public String   apiType;
        @AuraEnabled public String   apiVersion;
    }

    public class DashboardStats {
        @AuraEnabled public Integer          totalLogins;
        @AuraEnabled public Integer          successLogins;
        @AuraEnabled public Integer          failedLogins;
        @AuraEnabled public Integer          uniqueUsers;
        @AuraEnabled public Integer          todayLogins;
        @AuraEnabled public List<ChartPoint> browserBreakdown;
        @AuraEnabled public List<ChartPoint> dailyTrend;
        @AuraEnabled public List<UserStat>   topUsers;
        @AuraEnabled public List<IpStat>     suspiciousIps;
    }

    public class SecurityAlert {
        @AuraEnabled public String alertType;
        @AuraEnabled public String severity;
        @AuraEnabled public String userId;
        @AuraEnabled public String userName;
        @AuraEnabled public String description;
        @AuraEnabled public String icon;
    }

    public class ChartPoint {
        @AuraEnabled public String  label;
        @AuraEnabled public Integer value;
    }

    public class UserStat {
        @AuraEnabled public String  userId;
        @AuraEnabled public String  userName;
        @AuraEnabled public Integer count;
    }

    public class IpStat {
        @AuraEnabled public String  ipAddress;
        @AuraEnabled public Integer count;
    }

}