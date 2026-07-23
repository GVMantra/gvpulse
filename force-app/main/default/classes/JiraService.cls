/**
 * @description
 * Service class responsible for integrating with Jira's REST API to retrieve
 * issues and their associated worklogs, and for transforming that raw Jira
 * data into the shape expected by the Time Tracker UI (TimeTrackerResponse).
 *
 * This class handles:
 *   1. Building a JQL query and calling Jira's search endpoint via a
 *      Named Credential.
 *   2. Parsing the raw JSON response from Jira.
 *   3. Aggregating worklog hours per resource (author) and per date,
 *      including totals across all resources/dates.
 *
 * All callouts are routed through the "Jira_Integration" Named Credential
 * so that authentication details are managed declaratively rather than
 * hard-coded in Apex.
 */
public with sharing class JiraService {

    // Named Credential used for all outbound callouts to Jira.
    private static final String NAMED_CREDENTIAL = 'callout:Jira_Integration';

    /**
     * @description
     * Retrieves all Jira issues that have worklogs within the given date
     * range (optionally scoped to a specific project), and aggregates those
     * worklogs into a TimeTrackerResponse suitable for display in the UI
     * (e.g. hours per resource per day, daily totals, grand total).
     *
     * @param startDate  Start of the date range (inclusive) to search worklogs for.
     * @param endDate    End of the date range (inclusive) to search worklogs for.
     * @param projectKey Optional Jira project key to restrict the search to a
     *                   single project. If blank, worklogs across all projects
     *                   are considered.
     * @return TimeTrackerResponse containing date headers, per-resource hour
     *         breakdowns, per-date totals, and the grand total of hours.
     * @throws AuraHandledException if the callout to Jira does not return a
     *         200 status code.
     */
    public static TimeTrackerResponse getIssuesWithWorklogs(
        Date startDate,
        Date endDate,
        String projectKey
    ) {

        String jql;

        // Build the JQL filter. When no project is specified, search across
        // all projects; otherwise scope the search to the given project key.
        if (String.isBlank(projectKey)) {

            jql =
                'worklogDate >= "' + String.valueOf(startDate) + '"' +
                ' AND worklogDate <= "' + String.valueOf(endDate) + '"';

        } else {

            jql =
                'project = "' + projectKey + '"' +
                ' AND worklogDate >= "' + String.valueOf(startDate) + '"' +
                ' AND worklogDate <= "' + String.valueOf(endDate) + '"';

        }

        // Construct the HTTP GET request against Jira's JQL search endpoint,
        // requesting only the fields needed (summary and worklog details).
        HttpRequest req = new HttpRequest();

        req.setEndpoint(
            NAMED_CREDENTIAL +
            '/rest/api/3/search/jql?jql=' +
            EncodingUtil.urlEncode(jql,'UTF-8') +
            '&fields=summary,worklog'
        );

        req.setMethod('GET');
        req.setHeader('Accept','application/json');
        req.setTimeout(120000);

        Http http = new Http();

        HttpResponse res = http.send(req);

        // Surface any non-success response back to the caller as an
        // AuraHandledException so it can be displayed in the UI.
        if(res.getStatusCode()!=200){

            throw new AuraHandledException(
                'Jira Error : ' +
                res.getStatusCode() +
                '\n' +
                res.getBody()
            );

        }

        // Deserialize the raw JSON response body into a generic map for
        // further processing by buildResponse().
        Map<String,Object> response =
            (Map<String,Object>)JSON.deserializeUntyped(res.getBody());

        return buildResponse(response,startDate,endDate);

    }

    /**
     * @description
     * Transforms the raw, deserialized Jira search response into a
     * TimeTrackerResponse. This includes:
     *   - Seeding a complete list of DateHeader entries (and zeroed date
     *     totals) for every calendar day in the requested range, including
     *     weekends.
     *   - Iterating over each returned issue and its worklogs, attributing
     *     hours to the correct resource (worklog author) and date.
     *   - Filtering out worklog entries that fall outside the requested
     *     date range (see inline note below on Jira's JQL behavior).
     *   - Backfilling any date within the range that a given resource has
     *     no hours logged against, so every resource has an entry for every
     *     date header.
     *   - Sorting resources alphabetically by name.
     *
     * @param response   Raw Jira response deserialized into a generic map
     *                    (expected to contain an "issues" list).
     * @param startDate  Start of the requested date range (inclusive), used
     *                    to seed date headers/totals and filter worklogs.
     * @param endDate    End of the requested date range (inclusive), used to
     *                    seed date headers/totals and filter worklogs.
     * @return A fully populated TimeTrackerResponse ready to be returned to
     *         the UI.
     */
    private static TimeTrackerResponse buildResponse(

        Map<String,Object> response,
        Date startDate,
        Date endDate

    ){

        TimeTrackerResponse result = new TimeTrackerResponse();

        // Keyed by resource display name so worklogs across multiple issues
        // can be aggregated onto a single ResourceWrapper per person.
        Map<String,TimeTrackerResponse.ResourceWrapper> resourceMap =
            new Map<String,TimeTrackerResponse.ResourceWrapper>();


        //=========================
        // Generate complete date range
        //=========================
        // Build a DateHeader (and a zeroed dateTotals entry) for every single
        // day between startDate and endDate inclusive, so the UI always has
        // a full, contiguous set of date columns to render regardless of
        // whether any worklogs exist for a given day.

        for(Date d=startDate; d<=endDate; d=d.addDays(1)){

            TimeTrackerResponse.DateHeader header =
                new TimeTrackerResponse.DateHeader();

            header.dateValue = String.valueOf(d);

            header.label = String.valueOf(d.day());

            DateTime dt = DateTime.newInstance(d, Time.newInstance(0,0,0,0));

            header.month = dt.format('MMM');   // Jan, Feb, Mar...

            header.dayName = dt.format('EEE');

            Integer dayOfWeek = Integer.valueOf(dt.format('u'));

            // ISO-8601 day-of-week: 6 = Saturday, 7 = Sunday.
            header.isWeekend =
                dayOfWeek==6 || dayOfWeek==7;

            result.headers.add(header);

            result.dateTotals.put(header.dateValue,0);

        }


        List<Object> issues =
            (List<Object>)response.get('issues');

        // No issues returned by Jira for this query — return the response
        // with date headers/totals seeded but no resource data.
        if(issues==null){
            return result;
        }


        // Iterate every issue returned by the Jira search.
        for(Object issueObj : issues){

            Map<String,Object> issue =
                (Map<String,Object>)issueObj;

            String issueKey =
                (String)issue.get('key');

            Map<String,Object> fields =
                (Map<String,Object>)issue.get('fields');

            // Defensive check: skip issues with no fields payload.
            if(fields==null){
                continue;
            }

            String issueSummary =
                (String)fields.get('summary');

            Map<String,Object> worklog =
                (Map<String,Object>)fields.get('worklog');

            // Skip issues that have no worklog object at all.
            if(worklog==null){
                continue;
            }

            List<Object> worklogs =
                (List<Object>)worklog.get('worklogs');

            // Skip issues whose worklog object has no worklogs list.
            if(worklogs==null){
                continue;
            }


            // Iterate every individual worklog entry recorded on this issue.
            for(Object worklogObj : worklogs){

                Map<String,Object> wl =
                    (Map<String,Object>)worklogObj;

                Map<String,Object> author =
                    (Map<String,Object>)wl.get('author');

                // Defensive check: skip worklogs with no author info.
                if(author==null){
                    continue;
                }

                String resourceName =
                    (String)author.get('displayName');

                String started =
                    (String)wl.get('started');

                // Extract just the date portion (YYYY-MM-DD) from the
                // worklog's "started" timestamp.
                Date workDate =
                    Date.valueOf(started.substring(0,10));

                //=========================
                // FIX: Jira's worklogDate JQL filter matches the
                // issue if ANY worklog on it falls in range, but
                // returns ALL worklogs on that issue regardless of
                // date. Skip any worklog entry that falls outside
                // the requested range so we don't touch a dateKey
                // that was never seeded in dateTotals / hoursByDate.
                //=========================

                if(workDate < startDate || workDate > endDate){
                    continue;
                }

                // Convert logged time from seconds to hours, rounded to
                // two decimal places.
                Decimal hours =
                    (((Decimal)wl.get('timeSpentSeconds'))/3600).setScale(2);

                String dateKey =
                    String.valueOf(workDate);


                // Lazily create a ResourceWrapper the first time we
                // encounter a given resource (worklog author).
                if(!resourceMap.containsKey(resourceName)){

                    TimeTrackerResponse.ResourceWrapper wrapper =
                        new TimeTrackerResponse.ResourceWrapper();

                    wrapper.resourceName = resourceName;

                    resourceMap.put(resourceName,wrapper);

                }

                TimeTrackerResponse.ResourceWrapper wrapper =
                    resourceMap.get(resourceName);


                // Accumulate this worklog's hours into the resource's
                // running total.
                wrapper.totalHours += hours;


                // Accumulate hours for this resource on this specific date.
                if(!wrapper.hoursByDate.containsKey(dateKey)){
                    wrapper.hoursByDate.put(dateKey,0);
                }

                wrapper.hoursByDate.put(
                    dateKey,
                    wrapper.hoursByDate.get(dateKey)+hours
                );


                // Track which issues (and their summaries) this resource
                // has logged time against.
                wrapper.issueSummaryMap.put(
                    issueKey,
                    issueSummary
                );


                // Accumulate this worklog's hours into the overall
                // per-date total across all resources.
                result.dateTotals.put(
                    dateKey,
                    result.dateTotals.get(dateKey)+hours
                );

                // Accumulate this worklog's hours into the overall
                // grand total across all resources and dates.
                result.grandTotal += hours;

            }

        }


        //=========================
        // Fill missing dates with 0
        //=========================
        // Ensure every resource has an entry (defaulting to 0) for every
        // date header in the range, even days they logged no time, so the
        // UI can render a complete grid without null-checking.

        for(TimeTrackerResponse.ResourceWrapper wrapper : resourceMap.values()){

            for(TimeTrackerResponse.DateHeader header : result.headers){

                if(!wrapper.hoursByDate.containsKey(header.dateValue)){

                    wrapper.hoursByDate.put(
                        header.dateValue,
                        0
                    );

                }

            }

            result.resources.add(wrapper);

        }


        //=========================
        // Sort Resources
        //=========================
        // Present resources in a predictable, case-insensitive alphabetical
        // order by display name.

        result.resources.sort(new ResourceSorter());

        return result;

    }


    /**
     * @description
     * Comparator used to sort ResourceWrapper instances alphabetically
     * (case-insensitively) by resourceName, so the Time Tracker UI displays
     * resources in a consistent, predictable order.
     */
    public class ResourceSorter
        implements Comparator<TimeTrackerResponse.ResourceWrapper>{

        /**
         * @description Compares two ResourceWrapper instances by their
         * lower-cased resourceName, treating null names as empty strings.
         * @param a First resource to compare.
         * @param b Second resource to compare.
         * @return Standard comparator result: negative if a < b, zero if
         *         equal, positive if a > b.
         */
        public Integer compare(

            TimeTrackerResponse.ResourceWrapper a,
            TimeTrackerResponse.ResourceWrapper b

        ){

            String nameA = a.resourceName == null ? '' : a.resourceName.toLowerCase();
            String nameB = b.resourceName == null ? '' : b.resourceName.toLowerCase();

            return nameA.compareTo(nameB);

        }

    }

}