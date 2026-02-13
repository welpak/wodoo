const { chromium } = require('playwright');
const XLSX = require('xlsx');

(async () => {
    const browser = await chromium.launch({ headless: true });
    // Create a new context with a larger viewport for better visibility of elements
    const context = await browser.newContext({ viewport: { width: 1280, height: 1024 } });
    const page = await context.newPage();

    // Initialize Workbook
    const workbook = XLSX.utils.book_new();
    const masterData = [];
    const headers = ['Industry Code', 'Industry Name', 'Company', 'Street', 'City', 'County', 'Description', 'Size', 'Annual Sales', 'Detail URL'];

    try {
        console.log('Navigating to main page...');
        await page.goto('https://accessnc.nccommerce.com/business/business_custom_search_infogroup.html');

        // Go to Advanced Search
        await page.click('a[href="#Advanced_Search"]');
        await page.waitForTimeout(2000);

        // Select Area Type: County
        console.log('Selecting Area Type: County...');
        await page.selectOption('#regionCategory', { label: 'County' });
        await page.waitForTimeout(3000); // Wait for counties to load

        // Select Area Name: Franklin (37069)
        console.log('Selecting Area Name: Franklin...');
        await page.selectOption('#region', { value: '37069' });

        // Extract Industry Options
        console.log('Extracting Industry Options...');
        const industries = await page.evaluate(() => {
            const container = document.querySelector('#frmSelect fieldset:nth-child(3)');
            const select = container.querySelector('select');
            return Array.from(select.options)
                .map(o => ({
                    value: o.value,
                    name: o.getAttribute('data-subtext') ? `${o.value} ${o.getAttribute('data-subtext')}` : o.value, // Combine Code + Name
                    code: o.value
                }))
                .filter(o => o.value); // Remove empty placeholders
        });

        console.log(`Found ${industries.length} industries to process.`);

        // Loop through industries
        // For testing, maybe limit? No, user said "iterate through all".
        // But for safety in a long run, I'll print progress.

        for (let i = 0; i < industries.length; i++) {
            const industry = industries[i];
            console.log(`[${i + 1}/${industries.length}] Processing: ${industry.name}`);

            let popup = null;
            try {
                // Select Industry in the dropdown
                await page.selectOption('#IndustryGroup2', industry.value);

                // Click Submit Button
                // The button is inside #Advanced_Search
                const [newPopup] = await Promise.all([
                    page.waitForEvent('popup', { timeout: 30000 }), // Wait for new tab
                    page.click('#Advanced_Search button[type="submit"]')
                ]);
                popup = newPopup;
                await popup.waitForLoadState('domcontentloaded');
                await popup.waitForTimeout(2000); // Wait for table or "No records"

                // Check for "0 matched records"
                const bodyText = await popup.innerText('body');
                if (bodyText.includes('0 matched records')) {
                    console.log(`  No records found for ${industry.name}.`);
                    await popup.close();
                    continue;
                }

                // Wait for table
                try {
                    await popup.waitForSelector('table.table', { timeout: 5000 });
                } catch (e) {
                    console.log(`  Table not found for ${industry.name} (possibly no results).`);
                    await popup.close();
                    continue;
                }

                // Sort by Annual Sales (Click Header Twice for Descending)
                // Header link contains "sortOrder=sales"
                const salesHeader = popup.locator('a[href*="sortOrder=sales"]');
                if (await salesHeader.count() > 0) {
                     // Click once (Ascending?)
                    await salesHeader.first().click();
                    await popup.waitForLoadState('domcontentloaded');
                    await popup.waitForTimeout(1000);

                    // Click again (Descending?)
                    // The user said "Click... It will filter lowest to highest. Click... This will then filter highest to lowest. This is what we want."
                    // So distinct clicks are needed.
                    // We need to re-locate element after page reload
                    await popup.locator('a[href*="sortOrder=sales"]').first().click();
                    await popup.waitForLoadState('domcontentloaded');
                    await popup.waitForTimeout(1000);
                }

                // Scrape Pages
                let hasNextPage = true;
                const industryData = [];

                while (hasNextPage) {
                    const rows = await popup.$$('table.table tbody tr');
                    for (const row of rows) {
                        // Skip header rows (th)
                        const isHeader = await row.$('th');
                        if (isHeader) continue;

                        const cols = await row.$$('td');
                        if (cols.length < 7) continue;

                        const company = (await cols[0].innerText()).trim();
                        const street = (await cols[1].innerText()).trim();
                        const city = (await cols[2].innerText()).trim();
                        const county = (await cols[3].innerText()).trim();
                        const desc = (await cols[4].innerText()).trim();
                        const size = (await cols[5].innerText()).trim();
                        const salesRaw = (await cols[6].innerText()).trim();

                        // Detail URL
                        let detailUrl = '';
                        const linkEl = await cols[cols.length - 1].$('a'); // Last column usually has "Detail" or "Map"
                        // Or check specific column for Detail. User said "copy the 'Detail' hyper link".
                        // Let's check if the link text is "Detail" or implies it.
                        // If not found in last col, search all cols.
                        if (linkEl) {
                             const href = await linkEl.getAttribute('href');
                             if (href) detailUrl = href.startsWith('http') ? href : `https://accessnc.nccommerce.com${href}`;
                        } else {
                            // Try finding any 'Detail' link in the row
                            const detailLink = await row.getByText('Detail').first();
                            if (await detailLink.count() > 0) {
                                const href = await detailLink.getAttribute('href');
                                if (href) detailUrl = href.startsWith('http') ? href : `https://accessnc.nccommerce.com${href}`;
                            }
                        }

                        // Filter Logic
                        // Accept: >= $1 Million OR "$500,000-$1 Million"
                        // Ranges seen: "$500,000-$1 Million", "$1 Million-$2.5 Million", "$2.5 Million-$5 Million", etc.
                        // Reject: "<$500,000" (implied)

                        let include = false;
                        const salesClean = salesRaw.replace(/[$,\s]/g, '').toLowerCase(); // "1million-2.5million"

                        if (salesRaw.includes('$500,000-$1 Million')) {
                            include = true;
                        } else if (salesRaw.includes('Million')) {
                            // Any range mentioning Million (e.g. "1 Million...", "2.5 Million...") usually means >= 1M
                            // Unless it says "Less than 1 Million" but we handled 500k-1M above.
                            // Assuming ranges are standard like "1-2.5", "2.5-5", etc.
                            // If it's a specific number >= 1,000,000
                             include = true;
                        } else {
                             // Check for exact number
                             const val = parseFloat(salesClean);
                             if (!isNaN(val) && val >= 1000000) {
                                 include = true;
                             }
                        }

                        if (include) {
                            const record = {
                                'Industry Code': industry.code,
                                'Industry Name': industry.name,
                                'Company': company,
                                'Street': street,
                                'City': city,
                                'County': county,
                                'Description': desc,
                                'Size': size,
                                'Annual Sales': salesRaw,
                                'Detail URL': detailUrl
                            };
                            industryData.push(record);
                            masterData.push(record);
                        }
                    }

                    // Pagination
                    // User said: "https://accessnc.nccommerce.com/BusinessSearch/Company/paging" might be the URL.
                    // Look for "Next" link.
                    // Common selectors: 'a[rel="next"]', 'text=Next', 'text=›'
                    const nextBtn = popup.locator('.pagination li:not(.disabled) a:has-text("›"), .pagination li:not(.disabled) a:has-text("Next")');
                    if (await nextBtn.count() > 0 && await nextBtn.first().isVisible()) {
                        console.log(`  Navigating to next page...`);
                        await nextBtn.first().click();
                        await popup.waitForLoadState('domcontentloaded');
                        await popup.waitForTimeout(1000);
                    } else {
                        hasNextPage = false;
                    }
                }

                // Add to Workbook if data found
                if (industryData.length > 0) {
                    console.log(`  Found ${industryData.length} valid records.`);
                    const ws = XLSX.utils.json_to_sheet(industryData, { header: headers });
                    // Sheet name limit is 31 chars.
                    // Use Code + truncated name
                    let sheetName = `${industry.code} ${industry.name}`.replace(/[\\/*[\]:?]/g, ''); // Remove invalid chars
                    if (sheetName.length > 31) sheetName = sheetName.substring(0, 31);

                    // Ensure unique sheet name
                    if (workbook.Sheets[sheetName]) {
                         sheetName = `${industry.code}`; // Fallback to code
                    }

                    XLSX.utils.book_append_sheet(workbook, ws, sheetName);
                } else {
                    console.log(`  No records met the criteria.`);
                }

                await popup.close();

            } catch (e) {
                console.error(`  Error processing ${industry.name}:`, e.message);
                if (popup && !popup.isClosed()) await popup.close();
            }
        }

        // Add Master Sheet
        if (masterData.length > 0) {
            console.log(`Total records extracted: ${masterData.length}`);
            const masterWS = XLSX.utils.json_to_sheet(masterData, { header: headers });
            XLSX.utils.book_append_sheet(workbook, masterWS, "Master List");
        } else {
            console.log("No records found across all industries.");
        }

        // Save File
        XLSX.writeFile(workbook, 'NC_Businesses.xlsx');
        console.log('Scraping completed. Saved to NC_Businesses.xlsx');

    } catch (error) {
        console.error('Fatal Error:', error);
    } finally {
        await browser.close();
    }
})();
