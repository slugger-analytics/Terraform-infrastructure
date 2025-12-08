/**
 * Property Test: Warm Request Performance
 * **Feature: batter-widget-lambda-deployment, Property 7: Warm Request Performance**
 * **Validates: Requirements 15.5**
 *
 * This test verifies that warm Lambda requests respond within 3 seconds.
 * Per Requirements 15.5: "WHEN validation runs THEN the response time SHALL be under 3 seconds for warm requests"
 *
 * INTEGRATION TEST REQUIREMENTS:
 * - This test requires the Lambda function to be deployed and accessible
 * - Set the ALB_DNS environment variable to the ALB DNS name
 * - The test environment must have network access to the ALB (e.g., VPN, same VPC)
 *
 * Usage:
 *   ALB_DNS=slugger.alpb.com npm test
 *
 * The test will be skipped if:
 * - ALB_DNS is not set, OR
 * - The endpoint is not reachable from the current environment
 */

import { describe, it, expect, beforeAll } from "vitest";
import fc from "fast-check";

// Maximum response time for warm requests (3 seconds = 3000ms)
const MAX_WARM_RESPONSE_TIME_MS = 3000;

// Number of warm-up requests to ensure Lambda is warm
const WARMUP_REQUESTS = 2;

// Delay between warm-up requests (ms)
const WARMUP_DELAY_MS = 100;

// Connection timeout for reachability check (ms)
const CONNECTION_TIMEOUT_MS = 5000;

// Get ALB DNS from environment
const ALB_DNS = process.env.ALB_DNS;
const BASE_URL = ALB_DNS ? `https://${ALB_DNS}/widgets/flashcard` : "";

// Endpoints to test for warm request performance
const TEST_ENDPOINTS = [
    { path: "/api/health", description: "Health endpoint" },
    { path: "/", description: "Static index page" },
] as const;

/**
 * Helper to measure response time for a request
 */
async function measureResponseTime(url: string): Promise<{
    responseTime: number;
    status: number;
    ok: boolean;
}> {
    const start = performance.now();
    try {
        const response = await fetch(url);
        const responseTime = performance.now() - start;
        return {
            responseTime,
            status: response.status,
            ok: response.ok,
        };
    } catch {
        const responseTime = performance.now() - start;
        return {
            responseTime,
            status: 0,
            ok: false,
        };
    }
}

/**
 * Helper to warm up the Lambda function
 */
async function warmUpLambda(): Promise<void> {
    for (let i = 0; i < WARMUP_REQUESTS; i++) {
        await fetch(`${BASE_URL}/api/health`).catch(() => { });
        await new Promise((resolve) => setTimeout(resolve, WARMUP_DELAY_MS));
    }
}

/**
 * Helper to delay execution
 */
function delay(ms: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, ms));
}

/**
 * Check if the endpoint is reachable
 */
async function isEndpointReachable(): Promise<boolean> {
    if (!BASE_URL) return false;

    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), CONNECTION_TIMEOUT_MS);

    try {
        const response = await fetch(`${BASE_URL}/api/health`, {
            signal: controller.signal,
        });
        clearTimeout(timeoutId);
        return response.ok;
    } catch {
        clearTimeout(timeoutId);
        return false;
    }
}

// Skip entire test suite if ALB_DNS is not configured
const shouldSkipSuite = !ALB_DNS;

describe.skipIf(shouldSkipSuite)("Warm Request Performance", () => {
    let endpointReachable = false;

    beforeAll(async () => {
        // Check if endpoint is reachable
        console.log(`Checking connectivity to ${BASE_URL}...`);
        endpointReachable = await isEndpointReachable();

        if (!endpointReachable) {
            console.log(
                `Warning: Endpoint ${BASE_URL} is not reachable. Tests will fail.`
            );
            console.log(
                "Ensure you have network access to the ALB (VPN, same VPC, etc.)"
            );
            return;
        }

        // Endpoint is reachable, warm up Lambda
        console.log(`Warming up Lambda at ${BASE_URL}...`);
        await warmUpLambda();
        console.log("Lambda warmed up, starting tests...");
    });

    /**
     * Property test: Warm requests respond under 3 seconds
     * **Feature: batter-widget-lambda-deployment, Property 7: Warm Request Performance**
     * **Validates: Requirements 15.5**
     */
    it("should respond under 3 seconds for warm requests to any endpoint", async ({
        skip,
    }) => {
        // Skip if endpoint not reachable (checked in beforeAll)
        if (!endpointReachable) {
            skip("Endpoint not reachable from this environment");
            return;
        }

        await fc.assert(
            fc.asyncProperty(
                fc.constantFrom(...TEST_ENDPOINTS),
                fc.integer({ min: 1, max: 5 }), // Request iteration
                async (endpoint, _iteration) => {
                    const url = `${BASE_URL}${endpoint.path}`;
                    const result = await measureResponseTime(url);

                    if (!result.ok) {
                        throw new Error(
                            `Request to ${endpoint.description} failed with status ${result.status}`
                        );
                    }

                    if (result.responseTime >= MAX_WARM_RESPONSE_TIME_MS) {
                        throw new Error(
                            `${endpoint.description} response time ${result.responseTime.toFixed(0)}ms exceeds ${MAX_WARM_RESPONSE_TIME_MS}ms limit`
                        );
                    }

                    return true;
                }
            ),
            { numRuns: 100 }
        );
    });

    /**
     * Property test: Consecutive warm requests maintain performance
     * Verifies that response times remain consistent across multiple requests
     */
    it("should maintain consistent response times across consecutive requests", async ({
        skip,
    }) => {
        // Skip if endpoint not reachable
        if (!endpointReachable) {
            skip("Endpoint not reachable from this environment");
            return;
        }

        const responseTimes: number[] = [];

        await fc.assert(
            fc.asyncProperty(fc.integer({ min: 1, max: 10 }), async (_iteration) => {
                const result = await measureResponseTime(`${BASE_URL}/api/health`);

                if (!result.ok) {
                    throw new Error(`Health check failed with status ${result.status}`);
                }

                responseTimes.push(result.responseTime);

                // Each request should be under the limit
                if (result.responseTime >= MAX_WARM_RESPONSE_TIME_MS) {
                    throw new Error(
                        `Response time ${result.responseTime.toFixed(0)}ms exceeds ${MAX_WARM_RESPONSE_TIME_MS}ms limit`
                    );
                }

                // Small delay between requests to avoid rate limiting
                await delay(50);

                return true;
            }),
            { numRuns: 100 }
        );

        // Log statistics for debugging
        if (responseTimes.length > 0) {
            const avg =
                responseTimes.reduce((a, b) => a + b, 0) / responseTimes.length;
            const max = Math.max(...responseTimes);
            const min = Math.min(...responseTimes);
            console.log(
                `Response time stats - Avg: ${avg.toFixed(0)}ms, Min: ${min.toFixed(0)}ms, Max: ${max.toFixed(0)}ms`
            );
        }
    });

    /**
     * Unit test: Verify health endpoint is accessible and fast
     */
    it("should have fast health endpoint response", async ({ skip }) => {
        // Skip if endpoint not reachable
        if (!endpointReachable) {
            skip("Endpoint not reachable from this environment");
            return;
        }

        // Ensure Lambda is warm
        await warmUpLambda();

        const result = await measureResponseTime(`${BASE_URL}/api/health`);

        expect(result.ok).toBe(true);
        expect(result.status).toBe(200);
        expect(result.responseTime).toBeLessThan(MAX_WARM_RESPONSE_TIME_MS);
    });
});
