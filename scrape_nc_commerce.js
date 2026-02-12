const { chromium } = require('playwright');
const createCsvWriter = require('csv-writer').createObjectCsvWriter;
const fs = require('fs');

(async () => {
    const browser = await chromium.launch({ headless: true });
    const context = await browser.newContext();
    const page = await context.newPage();

    // Setup CSV writers
    const mainCsvWriter = createCsvWriter({
        path: 'companies_over_1m.csv',
        header: [
            { id: 'company', title: 'Company' },
            { id: 'street', title: 'Street' },
            { id: 'city', title: 'City' },
            { id: 'county', title: 'County' },
            { id: 'desc', title: 'Business Description' },
            { id: 'size', title: 'Company Size' },
            { id: 'sales', title: 'Annual Sales' },
            { id: 'detailUrl', title: 'Detail URL' },
            { id: 'naics', title: 'NAICS' }
        ]
    });

    const reviewCsvWriter = createCsvWriter({
        path: 'companies_review.csv',
        header: [
            { id: 'company', title: 'Company' },
            { id: 'sales', title: 'Annual Sales' },
            { id: 'detailUrl', title: 'Detail URL' },
            { id: 'naics', title: 'NAICS' },
            { id: 'reason', title: 'Reason' }
        ]
    });

    try {
        console.log('Navigating to main page...');
        await page.goto('https://accessnc.nccommerce.com/business/business_custom_search_infogroup.html');

        // Go to Advanced Search
        await page.click('a[href="#Advanced_Search"]');
        await page.waitForTimeout(1000);

        // Select Area Type: County
        await page.evaluate(() => {
            const select = document.querySelector('#regionCategory');
            select.value = 'County';
            select.dispatchEvent(new Event('change'));
        });
        await page.waitForTimeout(2000);

        // Select Area Name: Vance
        await page.evaluate(() => {
            const select = document.querySelector('#region');
            select.value = '37181';
            select.dispatchEvent(new Event('change'));
        });

        // Extract NAICS options
        const options = await page.evaluate(() => {
            const select = document.querySelector('#IndustryGroup2');
            return Array.from(select.options).map(o => ({
                value: o.value,
                text: o.innerText.trim(),
                label: o.getAttribute('data-subtext') || o.innerText.trim()
            }));
        });

        // Filter NAICS options
        const startCode = "1124";
        const endCode = "9281";

        let startIndex = options.findIndex(o => o.value === startCode);
        let endIndex = options.findIndex(o => o.value === endCode);

        if (startIndex === -1) startIndex = 0;
        if (endIndex === -1) endIndex = options.length - 1;

        const targetOptions = options.slice(startIndex, endIndex + 1);
        console.log(`Found ${targetOptions.length} industries to process from ${startCode} to ${endCode}.`);

        for (const option of targetOptions) {
            if (!option.value) continue; // Skip empty placeholder

            console.log(`Processing NAICS: ${option.value} - ${option.label}`);

            let popup;
            try {
                // Select Industry
                await page.evaluate((val) => {
                    const select = document.querySelector('#IndustryGroup2');
                    select.value = val;
                    select.dispatchEvent(new Event('change'));
                }, option.value);

                // Submit form and handle popup
                const [newPopup] = await Promise.all([
                    page.waitForEvent('popup', { timeout: 30000 }),
                    page.evaluate(() => {
                        document.querySelector('#Advanced_Search button[type="submit"]').click();
                    })
                ]);
                popup = newPopup;

                await popup.waitForLoadState('domcontentloaded');
                // Wait for either table row or "0 matched records" text
                // Check if there are results
                const bodyText = await popup.innerText('body');
                if (bodyText.includes('0 matched records')) {
                    console.log('  No records found.');
                    await popup.close();
                    continue;
                }

                await popup.waitForSelector('table.table', { timeout: 10000 });

                // Sort by Annual Sales
                // Click header
                // Note: The header link is <a href="/BusinessSearch/Company/sort?sortOrder=sales">Annual Sales</a>
                // Clicking it usually toggles. We want Descending ideally.
                // Let's click it once, check values.

                const salesHeaderSelector = 'a[href*="sortOrder=sales"]';
                if (await popup.$(salesHeaderSelector)) {
                    // Click to sort (Assuming default might be ascending or unsorted)
                    // The user suggested clicking it "to grab the largest companies".
                    // This implies clicking it creates a favorable order (likely Descending).
                    // We'll verify logic inside the loop.
                    await popup.click(salesHeaderSelector);
                    await popup.waitForLoadState('domcontentloaded');
                    await popup.waitForTimeout(1000); // Wait for sort
                }

                let hasNextPage = true;
                while (hasNextPage) {
                    // Extract Rows
                    const rows = await popup.$$('table.table tbody tr');
                    // Skip header row if it's inside tbody (it is in the HTML snippet)
                    // The header row has 'th' elements.

                    let recordsProcessed = 0;

                    for (const row of rows) {
                        // Check if header row
                        const isHeader = await row.$('th');
                        if (isHeader) continue;

                        const cols = await row.$$('td');
                        if (cols.length < 7) continue;

                        const company = await cols[0].innerText();
                        const street = await cols[1].innerText();
                        const city = await cols[2].innerText();
                        const county = await cols[3].innerText();
                        const desc = await cols[4].innerText();
                        const size = await cols[5].innerText();
                        const salesText = await cols[6].innerText();

                        // Detail URL
                        let detailUrl = '';
                        // Try finding any link in the last column
                        const linkEl = await cols[cols.length - 1].$('a');
                        if (linkEl) {
                            const href = await linkEl.getAttribute('href');
                            // Ensure absolute URL
                            if (href) {
                                detailUrl = href.startsWith('http') ? href : `https://accessnc.nccommerce.com${href}`;
                            }
                        }

                        // Parse Sales
                        // Remove '$', ',', and whitespace
                        const cleanSales = salesText.replace(/[$,\s]/g, '');
                        const salesVal = parseFloat(cleanSales);

                        if (!isNaN(salesVal)) {
                            if (salesVal >= 1000000) {
                                await mainCsvWriter.writeRecords([{
                                    company, street, city, county, desc, size, sales: salesText, detailUrl, naics: option.value
                                }]);
                                recordsProcessed++;
                            }
                        } else {
                            // "Data Unavailable" or other text
                            // User wants a separate spreadsheet for these
                            await reviewCsvWriter.writeRecords([{
                                company, sales: salesText, detailUrl, naics: option.value, reason: 'Sales not a number'
                            }]);
                        }
                    }

                    console.log(`  Processed records on page.`);

                    // Check for Next Page
                    // PagedList usually uses 'li.PagedList-skipToNext > a' or similar.
                    // Based on HTML snippet: <div class="pagination-container"><ul class="pagination"></ul></div>
                    // If multiple pages exist, the structure typically has Next button.
                    // Let's search for a link with text "›" or "»" or "Next"
                    // Or specific class.
                    const nextLink = await popup.$('.pagination li a[rel="next"]'); // Common in MVC PagedList
                    // Or check for text
                    // We will try a flexible selector
                    const nextBtn = await popup.getByRole('link', { name: '›', exact: true }).or(popup.getByRole('link', { name: 'Next' }));

                    if (await nextBtn.count() > 0 && await nextBtn.first().isVisible()) {
                        await nextBtn.first().click();
                        await popup.waitForLoadState('domcontentloaded');
                        await popup.waitForTimeout(1000);
                    } else {
                        hasNextPage = false;
                    }
                }

                await popup.close();

            } catch (e) {
                console.error(`  Error processing NAICS ${option.value}:`, e.message);
                if (popup && !popup.isClosed()) await popup.close();
            }
        }

        console.log('Scraping completed.');

    } catch (error) {
        console.error('Fatal Error:', error);
    } finally {
        await browser.close();
    }
})();
