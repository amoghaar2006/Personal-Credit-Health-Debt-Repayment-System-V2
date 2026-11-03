import { test, expect } from '@playwright/test'

test('dashboard renders its main heading', async ({ page }) => {
  await page.goto('/')
  await expect(page.getByRole('heading', { name: 'Good to see you.' })).toBeVisible()
})

test('sidebar navigates to loans module', async ({ page }) => {
  await page.goto('/')
  await page.getByRole('link', { name: 'Loans' }).click()
  await expect(page.getByRole('heading', { name: 'Loans' })).toBeVisible()
})
