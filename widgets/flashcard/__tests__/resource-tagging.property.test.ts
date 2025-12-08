/**
 * Property Test: Resource Tagging Consistency
 * **Feature: batter-widget-lambda-deployment, Property 6: Resource Tagging Consistency**
 * **Validates: Requirements 14.1, 14.2, 14.3, 14.4**
 *
 * This test verifies that all AWS resources created by Terraform have the required tags:
 * - Project=slugger
 * - Component=widget-flashcard
 * - Environment=production
 * - ManagedBy=terraform
 */

import { describe, it, expect } from "vitest";
import fc from "fast-check";
import * as fs from "fs";
import * as path from "path";

// Required tags per Requirements 14.1, 14.2, 14.3, 14.4
const REQUIRED_TAGS = {
    Project: "slugger",
    Component: "widget-flashcard",
    Environment: "production",
    ManagedBy: "terraform",
} as const;

// Resource types that support tagging in AWS
const TAGGABLE_RESOURCE_TYPES = [
    "aws_ecr_repository",
    "aws_iam_role",
    "aws_cloudwatch_log_group",
    "aws_lambda_function",
    "aws_lb_target_group",
    "aws_lb_listener_rule",
] as const;

interface TerraformResource {
    mode: string;
    type: string;
    name: string;
    instances: Array<{
        attributes: {
            tags?: Record<string, string>;
            tags_all?: Record<string, string>;
            [key: string]: unknown;
        };
    }>;
}

interface TerraformState {
    version: number;
    resources: TerraformResource[];
}

/**
 * Load and parse the Terraform state file
 */
function loadTerraformState(): TerraformState {
    const statePath = path.join(__dirname, "..", "terraform.tfstate");
    const stateContent = fs.readFileSync(statePath, "utf-8");
    return JSON.parse(stateContent) as TerraformState;
}

/**
 * Get all managed (non-data) resources that support tagging
 */
function getTaggableResources(state: TerraformState): TerraformResource[] {
    return state.resources.filter(
        (resource) =>
            resource.mode === "managed" &&
            TAGGABLE_RESOURCE_TYPES.includes(
                resource.type as (typeof TAGGABLE_RESOURCE_TYPES)[number]
            )
    );
}

/**
 * Check if a resource has all required tags with correct values
 */
function hasAllRequiredTags(resource: TerraformResource): {
    valid: boolean;
    missingTags: string[];
    incorrectTags: Array<{ tag: string; expected: string; actual: string }>;
} {
    const missingTags: string[] = [];
    const incorrectTags: Array<{
        tag: string;
        expected: string;
        actual: string;
    }> = [];

    // Get tags from the first instance (resources typically have one instance)
    const instance = resource.instances[0];
    if (!instance) {
        return {
            valid: false,
            missingTags: Object.keys(REQUIRED_TAGS),
            incorrectTags: [],
        };
    }

    // Use tags_all which includes inherited tags, or fall back to tags
    const tags = instance.attributes.tags_all || instance.attributes.tags || {};

    for (const [tagKey, expectedValue] of Object.entries(REQUIRED_TAGS)) {
        if (!(tagKey in tags)) {
            missingTags.push(tagKey);
        } else if (tags[tagKey] !== expectedValue) {
            incorrectTags.push({
                tag: tagKey,
                expected: expectedValue,
                actual: tags[tagKey],
            });
        }
    }

    return {
        valid: missingTags.length === 0 && incorrectTags.length === 0,
        missingTags,
        incorrectTags,
    };
}

describe("Resource Tagging Consistency", () => {
    /**
     * Property test: All taggable resources have required tags
     * **Feature: batter-widget-lambda-deployment, Property 6: Resource Tagging Consistency**
     * **Validates: Requirements 14.1, 14.2, 14.3, 14.4**
     */
    it("should have all required tags on all taggable resources", () => {
        const state = loadTerraformState();
        const taggableResources = getTaggableResources(state);

        // Ensure we have resources to test
        expect(taggableResources.length).toBeGreaterThan(0);

        // Property test: For any taggable resource, it should have all required tags
        fc.assert(
            fc.property(fc.constantFrom(...taggableResources), (resource) => {
                const result = hasAllRequiredTags(resource);

                if (!result.valid) {
                    const resourceId = `${resource.type}.${resource.name}`;
                    const errors: string[] = [];

                    if (result.missingTags.length > 0) {
                        errors.push(`Missing tags: ${result.missingTags.join(", ")}`);
                    }

                    if (result.incorrectTags.length > 0) {
                        const incorrectDetails = result.incorrectTags
                            .map((t) => `${t.tag}: expected "${t.expected}", got "${t.actual}"`)
                            .join("; ");
                        errors.push(`Incorrect tags: ${incorrectDetails}`);
                    }

                    throw new Error(
                        `Resource ${resourceId} has tagging issues: ${errors.join(". ")}`
                    );
                }

                return true;
            }),
            { numRuns: 100 }
        );
    });

    /**
     * Property test: Tag values are consistent across all resources
     * Verifies that the same tag key has the same value across all resources
     */
    it("should have consistent tag values across all resources", () => {
        const state = loadTerraformState();
        const taggableResources = getTaggableResources(state);

        // Collect all tag values by key
        const tagValuesByKey: Record<string, Set<string>> = {};

        for (const resource of taggableResources) {
            const instance = resource.instances[0];
            if (!instance) continue;

            const tags = instance.attributes.tags_all || instance.attributes.tags || {};

            for (const [key, value] of Object.entries(tags)) {
                if (!tagValuesByKey[key]) {
                    tagValuesByKey[key] = new Set();
                }
                tagValuesByKey[key].add(value);
            }
        }

        // Property test: For any required tag key, there should be exactly one value
        fc.assert(
            fc.property(
                fc.constantFrom(...Object.keys(REQUIRED_TAGS)),
                (tagKey) => {
                    const values = tagValuesByKey[tagKey];

                    if (!values || values.size === 0) {
                        throw new Error(`Tag "${tagKey}" not found on any resource`);
                    }

                    if (values.size > 1) {
                        throw new Error(
                            `Tag "${tagKey}" has inconsistent values: ${Array.from(values).join(", ")}`
                        );
                    }

                    // Verify the single value matches the expected value
                    const actualValue = Array.from(values)[0];
                    const expectedValue = REQUIRED_TAGS[tagKey as keyof typeof REQUIRED_TAGS];

                    if (actualValue !== expectedValue) {
                        throw new Error(
                            `Tag "${tagKey}" has value "${actualValue}", expected "${expectedValue}"`
                        );
                    }

                    return true;
                }
            ),
            { numRuns: 100 }
        );
    });

    /**
     * Unit test: Verify specific resource types are tagged
     */
    it("should tag all expected resource types", () => {
        const state = loadTerraformState();
        const taggableResources = getTaggableResources(state);

        // Get unique resource types that are tagged
        const taggedResourceTypes = new Set(
            taggableResources.map((r) => r.type)
        );

        // Verify we have the expected resource types
        const expectedTypes = [
            "aws_ecr_repository",
            "aws_iam_role",
            "aws_cloudwatch_log_group",
            "aws_lambda_function",
            "aws_lb_target_group",
            "aws_lb_listener_rule",
        ];

        for (const expectedType of expectedTypes) {
            expect(taggedResourceTypes.has(expectedType)).toBe(true);
        }
    });
});
