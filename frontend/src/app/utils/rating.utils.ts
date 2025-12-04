/**
 * Utility functions for rating-related operations
 */

/**
 * Converts a numeric rating to an array for star display
 * @param rating The rating value (typically 0-5)
 * @returns Array of 0s and 1s where 1 represents a filled star
 */
export function getStarArray(rating: number): number[] {
  return Array(5).fill(0).map((_, i) => i < Math.round(rating) ? 1 : 0);
}
