import { IExecuteFunctions, INodeExecutionData, INodeType, INodeTypeDescription } from "./n8n-types";

export class AllixiosWorkflowMonitor implements INodeType {
    description: INodeTypeDescription = {
        displayName: "Allixios Workflow Monitor",
        name: "allixiosWorkflowMonitor",
        icon: "file:allixios.svg",
        group: ["transform"],
        version: 1,
        description: "Monitor workflow performance and generate optimization recommendations",
        defaults: {
            name: "Allixios Workflow Monitor",
        },
        inputs: ["main"],
        outputs: ["main"],
        properties: [
            {
                displayName: "Workflow Instance ID",
                name: "workflowInstanceId",
                type: "string",
                default: "",
                description: "ID of the workflow instance to monitor",
                required: true,
            },
            {
                displayName: "Analysis Period (Hours)",
                name: "analysisPeriodHours",
                type: "number",
                default: 24,
                description: "Period for performance analysis in hours",
            },
            {
                displayName: "Generate Recommendations",
                name: "generateRecommendations",
                type: "boolean",
                default: true,
                description: "Generate optimization recommendations",
            },
            {
                displayName: "Alert Threshold",
                name: "alertThreshold",
                type: "options",
                options: [
                    { name: "Low (Error rate > 10%)", value: "low" },
                    { name: "Medium (Error rate > 5%)", value: "medium" },
                    { name: "High (Error rate > 2%)", value: "high" },
                ],
                default: "medium",
                description: "Threshold for generating alerts",
            }
        ],
    };

    async execute(this: IExecuteFunctions): Promise<INodeExecutionData[][]> {
        const items = this.getInputData();
        const returnData: INodeExecutionData[] = [];

        for (let i = 0; i < items.length; i++) {
            try {
                const workflowInstanceId = this.getNodeParameter("workflowInstanceId", i) as string;
                const analysisPeriodHours = this.getNodeParameter("analysisPeriodHours", i) as number;
                const generateRecommendations = this.getNodeParameter("generateRecommendations", i) as boolean;
                const alertThreshold = this.getNodeParameter("alertThreshold", i) as string;

                const supabaseUrl = process.env.SUPABASE_URL;
                const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

                const response = await fetch(`${supabaseUrl}/rest/v1/rpc/analyze_workflow_performance`, {
                    method: "POST",
                    headers: {
                        "Authorization": `Bearer ${supabaseKey}`,
                        "Content-Type": "application/json",
                    },
                    body: JSON.stringify({
                        p_workflow_instance_id: workflowInstanceId,
                        p_analysis_period_hours: analysisPeriodHours,
                        p_generate_recommendations: generateRecommendations,
                        p_alert_threshold: alertThreshold
                    }),
                });

                const result = await response.json();

                if (!response.ok) {
                    throw new Error(`Workflow monitoring failed: ${result.message || response.statusText}`);
                }

                returnData.push({
                    json: {
                        ...result,
                        monitored_at: new Date().toISOString(),
                        analysis_period_hours: analysisPeriodHours,
                        node_execution_id: this.getExecutionId(),
                    },
                });

            } catch (error) {
                if (this.continueOnFail()) {
                    returnData.push({
                        json: {
                            error: error.message,
                            workflow_instance_id: this.getNodeParameter("workflowInstanceId", i),
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