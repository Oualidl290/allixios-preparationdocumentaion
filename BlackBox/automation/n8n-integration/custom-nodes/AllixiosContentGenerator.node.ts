import { IExecuteFunctions, INodeExecutionData, INodeType, INodeTypeDescription } from "./n8n-types";

export class AllixiosContentGenerator implements INodeType {
    description: INodeTypeDescription = {
        displayName: "Allixios Content Generator",
        name: "allixiosContentGenerator",
        icon: "file:allixios.svg",
        group: ["transform"],
        version: 1,
        description: "Generate optimized content using Allixios AI engine",
        defaults: {
            name: "Allixios Content Generator",
        },
        inputs: ["main"],
        outputs: ["main"],
        properties: [
            {
                displayName: "Topic",
                name: "topic",
                type: "string",
                default: "",
                placeholder: "Enter content topic",
                description: "The main topic for content generation",
                required: true,
            },
            {
                displayName: "Niche ID",
                name: "nicheId",
                type: "string",
                default: "",
                description: "Target niche for the content",
                required: true,
            },
            {
                displayName: "Word Count",
                name: "wordCount",
                type: "number",
                default: 2000,
                description: "Target word count for the article",
            },
            {
                displayName: "Language",
                name: "language",
                type: "options",
                options: [
                    { name: "English", value: "en" },
                    { name: "Spanish", value: "es" },
                    { name: "French", value: "fr" },
                    { name: "German", value: "de" },
                    { name: "Italian", value: "it" },
                    { name: "Portuguese", value: "pt" },
                ],
                default: "en",
                description: "Content language",
            },
            {
                displayName: "Target Audience",
                name: "targetAudience",
                type: "string",
                default: "general",
                description: "Target audience for the content",
            },
            {
                displayName: "Quality Threshold",
                name: "qualityThreshold",
                type: "number",
                default: 85,
                description: "Minimum quality score (0-100)",
            },
            {
                displayName: "Include Images",
                name: "includeImages",
                type: "boolean",
                default: true,
                description: "Generate images for the content",
            },
            {
                displayName: "SEO Optimize",
                name: "seoOptimize",
                type: "boolean",
                default: true,
                description: "Apply SEO optimizations",
            }
        ],
    };

    async execute(this: IExecuteFunctions): Promise<INodeExecutionData[][]> {
        const items = this.getInputData();
        const returnData: INodeExecutionData[] = [];

        for (let i = 0; i < items.length; i++) {
            try {
                const topic = this.getNodeParameter("topic", i) as string;
                const nicheId = this.getNodeParameter("nicheId", i) as string;
                const wordCount = this.getNodeParameter("wordCount", i) as number;
                const language = this.getNodeParameter("language", i) as string;
                const targetAudience = this.getNodeParameter("targetAudience", i) as string;
                const qualityThreshold = this.getNodeParameter("qualityThreshold", i) as number;
                const includeImages = this.getNodeParameter("includeImages", i) as boolean;
                const seoOptimize = this.getNodeParameter("seoOptimize", i) as boolean;

                // Call Allixios content generation API
                const supabaseUrl = process.env.SUPABASE_URL;
                const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

                const response = await fetch(`${supabaseUrl}/rest/v1/rpc/generate_ai_content_enhanced`, {
                    method: "POST",
                    headers: {
                        "Authorization": `Bearer ${supabaseKey}`,
                        "Content-Type": "application/json",
                    },
                    body: JSON.stringify({
                        p_topic: topic,
                        p_niche_id: nicheId,
                        p_word_count: wordCount,
                        p_language: language,
                        p_target_audience: targetAudience,
                        p_quality_threshold: qualityThreshold,
                        p_include_images: includeImages,
                        p_seo_optimize: seoOptimize
                    }),
                });

                const result = await response.json();

                if (!response.ok) {
                    throw new Error(`Content generation failed: ${result.message || response.statusText}`);
                }

                returnData.push({
                    json: {
                        ...result,
                        generated_at: new Date().toISOString(),
                        node_execution_id: this.getExecutionId(),
                    },
                });

            } catch (error) {
                if (this.continueOnFail()) {
                    returnData.push({
                        json: {
                            error: error.message,
                            topic: this.getNodeParameter("topic", i),
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