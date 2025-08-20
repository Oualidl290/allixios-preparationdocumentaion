import { IExecuteFunctions, INodeExecutionData, INodeType, INodeTypeDescription } from "./n8n-types";

export class AllixiosAnalyticsProcessor implements INodeType {
    description: INodeTypeDescription = {
        displayName: "Allixios Analytics Processor",
        name: "allixiosAnalyticsProcessor",
        icon: "file:allixios.svg",
        group: ["transform"],
        version: 1,
        description: "Process analytics events using Allixios analytics engine",
        defaults: {
            name: "Allixios Analytics Processor",
        },
        inputs: ["main"],
        outputs: ["main"],
        properties: [
            {
                displayName: "Event Type",
                name: "eventType",
                type: "options",
                options: [
                    { name: "Page View", value: "page_view" },
                    { name: "Article Read", value: "article_read" },
                    { name: "Search", value: "search" },
                    { name: "Click", value: "click" },
                    { name: "Conversion", value: "conversion" },
                    { name: "Signup", value: "signup" },
                    { name: "Subscription", value: "subscription" },
                ],
                default: "page_view",
                description: "Type of analytics event",
                required: true,
            },
            {
                displayName: "User ID",
                name: "userId",
                type: "string",
                default: "",
                description: "User identifier",
                required: true,
            },
            {
                displayName: "Session ID",
                name: "sessionId",
                type: "string",
                default: "",
                description: "Session identifier",
            },
            {
                displayName: "Article ID",
                name: "articleId",
                type: "string",
                default: "",
                description: "Article ID (for article-related events)",
            },
            {
                displayName: "Event Metadata",
                name: "eventMetadata",
                type: "json",
                default: "{}",
                description: "Additional event data as JSON",
            },
            {
                displayName: "Process Real-time",
                name: "processRealtime",
                type: "boolean",
                default: true,
                description: "Process event in real-time",
            }
        ],
    };

    async execute(this: IExecuteFunctions): Promise<INodeExecutionData[][]> {
        const items = this.getInputData();
        const returnData: INodeExecutionData[] = [];

        for (let i = 0; i < items.length; i++) {
            try {
                const eventType = this.getNodeParameter("eventType", i) as string;
                const userId = this.getNodeParameter("userId", i) as string;
                const sessionId = this.getNodeParameter("sessionId", i) as string;
                const articleId = this.getNodeParameter("articleId", i) as string;
                const eventMetadata = this.getNodeParameter("eventMetadata", i) as object;
                const processRealtime = this.getNodeParameter("processRealtime", i) as boolean;

                const supabaseUrl = process.env.SUPABASE_URL;
                const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

                const eventData = {
                    event_type: eventType,
                    user_id: userId,
                    session_id: sessionId || `session_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
                    article_id: articleId || null,
                    timestamp: new Date().toISOString(),
                    metadata: eventMetadata,
                    ip_address: items[i].json.ip_address || "unknown",
                    user_agent: items[i].json.user_agent || "unknown",
                    referrer: items[i].json.referrer || null,
                };

                const response = await fetch(`${supabaseUrl}/rest/v1/rpc/process_analytics_event`, {
                    method: "POST",
                    headers: {
                        "Authorization": `Bearer ${supabaseKey}`,
                        "Content-Type": "application/json",
                    },
                    body: JSON.stringify({
                        p_event_data: eventData,
                        p_process_realtime: processRealtime
                    }),
                });

                const result = await response.json();

                if (!response.ok) {
                    throw new Error(`Analytics processing failed: ${result.message || response.statusText}`);
                }

                returnData.push({
                    json: {
                        ...result,
                        original_event: eventData,
                        processed_at: new Date().toISOString(),
                        node_execution_id: this.getExecutionId(),
                    },
                });

            } catch (error) {
                if (this.continueOnFail()) {
                    returnData.push({
                        json: {
                            error: error.message,
                            event_type: this.getNodeParameter("eventType", i),
                            user_id: this.getNodeParameter("userId", i),
                        },
                    });
                } else {
                    throw error;
                }
            }
        }

        return [returnData];
    }
}