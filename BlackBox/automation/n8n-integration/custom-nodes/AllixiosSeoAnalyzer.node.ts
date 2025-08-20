import { IExecuteFunctions, INodeExecutionData, INodeType, INodeTypeDescription } from "./n8n-types";

export class AllixiosSeoAnalyzer implements INodeType {
    description: INodeTypeDescription = {
        displayName: "Allixios SEO Analyzer",
        name: "allixiosSeoAnalyzer",
        icon: "file:allixios.svg",
        group: ["transform"],
        version: 1,
        description: "Analyze and optimize content for SEO using Allixios engine",
        defaults: {
            name: "Allixios SEO Analyzer",
        },
        inputs: ["main"],
        outputs: ["main"],
        properties: [
            {
                displayName: "Article ID",
                name: "articleId",
                type: "string",
                default: "",
                description: "ID of the article to analyze",
                required: true,
            },
            {
                displayName: "Analysis Type",
                name: "analysisType",
                type: "options",
                options: [
                    { name: "Full Analysis", value: "full" },
                    { name: "Quick Check", value: "quick" },
                    { name: "Competitive Analysis", value: "competitive" },
                ],
                default: "full",
                description: "Type of SEO analysis to perform",
            },
            {
                displayName: "Target Keywords",
                name: "targetKeywords",
                type: "string",
                default: "",
                description: "Comma-separated list of target keywords",
            },
            {
                displayName: "Competitor URLs",
                name: "competitorUrls",
                type: "string",
                default: "",
                description: "Comma-separated list of competitor URLs (for competitive analysis)",
            },
            {
                displayName: "Generate Recommendations",
                name: "generateRecommendations",
                type: "boolean",
                default: true,
                description: "Generate optimization recommendations",
            }
        ],
    };

    async execute(this: IExecuteFunctions): Promise<INodeExecutionData[][]> {
        const items = this.getInputData();
        const returnData: INodeExecutionData[] = [];

        for (let i = 0; i < items.length; i++) {
            try {
                const articleId = this.getNodeParameter("articleId", i) as string;
                const analysisType = this.getNodeParameter("analysisType", i) as string;
                const targetKeywords = this.getNodeParameter("targetKeywords", i) as string;
                const competitorUrls = this.getNodeParameter("competitorUrls", i) as string;
                const generateRecommendations = this.getNodeParameter("generateRecommendations", i) as boolean;

                const supabaseUrl = process.env.SUPABASE_URL;
                const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

                const response = await fetch(`${supabaseUrl}/rest/v1/rpc/analyze_seo_comprehensive`, {
                    method: "POST",
                    headers: {
                        "Authorization": `Bearer ${supabaseKey}`,
                        "Content-Type": "application/json",
                    },
                    body: JSON.stringify({
                        p_article_id: articleId,
                        p_analysis_type: analysisType,
                        p_target_keywords: targetKeywords.split(",").map(k => k.trim()).filter(k => k),
                        p_competitor_urls: competitorUrls.split(",").map(u => u.trim()).filter(u => u),
                        p_generate_recommendations: generateRecommendations
                    }),
                });

                const result = await response.json();

                if (!response.ok) {
                    throw new Error(`SEO analysis failed: ${result.message || response.statusText}`);
                }

                returnData.push({
                    json: {
                        ...result,
                        analyzed_at: new Date().toISOString(),
                        analysis_type: analysisType,
                        node_execution_id: this.getExecutionId(),
                    },
                });

            } catch (error) {
                if (this.continueOnFail()) {
                    returnData.push({
                        json: {
                            error: error.message,
                            article_id: this.getNodeParameter("articleId", i),
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