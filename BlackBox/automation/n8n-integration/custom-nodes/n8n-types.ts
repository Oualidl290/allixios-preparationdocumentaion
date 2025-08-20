// Type definitions for n8n custom nodes
// This file provides the necessary types when n8n-workflow is not available

export interface INodeExecutionData {
  json: { [key: string]: any };
  binary?: { [key: string]: any };
  pairedItem?: { item: number; input?: number } | { item: number; input?: number }[];
}

export interface INodeType {
  description: INodeTypeDescription;
  execute(this: IExecuteFunctions): Promise<INodeExecutionData[][]>;
}

export interface INodeTypeDescription {
  displayName: string;
  name: string;
  icon?: string;
  group: string[];
  version: number;
  description: string;
  defaults: {
    name: string;
  };
  inputs: string[];
  outputs: string[];
  properties: INodeProperties[];
}

export interface INodeProperties {
  displayName: string;
  name: string;
  type: string;
  default?: any;
  description?: string;
  required?: boolean;
  options?: Array<{ name: string; value: string }>;
  placeholder?: string;
}

export interface IExecuteFunctions {
  getInputData(): INodeExecutionData[];
  getNodeParameter(parameterName: string, itemIndex: number): any;
  continueOnFail(): boolean;
  getExecutionId(): string;
}