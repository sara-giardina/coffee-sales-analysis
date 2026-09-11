-- PROBLEMA 1: Consumatori di caffè
# Quante persone in ciascuna città si stima che consumino caffè, sapendo che il 25% della popolazione lo fa?
# Il numero di consumatori di caffè stimato in ogni città è pari alla popolazione*25/100. 
# Inserisco questi dati nella colonna di una nuova tabella city_staging2 che contiene anche gli stessi dati della tabella city originale.

CREATE TABLE `city_staging2` (
  `city_id` int DEFAULT NULL,
  `city_name` text,
  `population` int DEFAULT NULL,
  `estimated_rent` int DEFAULT NULL,
  `city_rank` int DEFAULT NULL,
  `estimated_consumers` float 
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO city_staging2
SELECT *,
(population*0.25) AS estimated_consumers
FROM city;

SELECT city_name, population, estimated_consumers
FROM city_staging2
ORDER BY population DESC; 

-- Abbiamo creato una tabella city_staging2 con gli stessi dati della tabella city e in più la colonna con i consumatori stimati. 
-- Da questa tabella si vede che le 5 città in cui si consuma più caffè sono (in ordine decrescente) Delhi, Mumbai, Kolkata, Bangalore e Chennai. 


-- PROBLEMA 2: Ricavo Totale delle vendite di caffè
# Qual è il ricavo totale generato dalle vendite di caffè in tutte le città nell'ultimo trimestre del 2023?

SELECT *
FROM sales
ORDER BY sale_id DESC;

SELECT *
FROM sales_staging
ORDER BY sale_id DESC
;

# Noto che la colonna sale_date non è di tipo date e quindi prima la converto. 
CREATE TABLE sales_staging
LIKE sales;

INSERT sales_staging
SELECT *
FROM sales;

ALTER TABLE sales_staging
MODIFY COLUMN sale_date DATE;

# Calcolo il totale delle vendite per giorno nell'ultimo trimestre del 2023
SELECT sale_date, SUM(total) AS tot_per_giorno
FROM sales_staging
WHERE sale_date LIKE '2023-1%' 
GROUP BY sale_date
ORDER BY sale_date;

# Il totale delle vendite nell'ultimo trimestre del 2023 è dato da:
WITH tot_giornaliero AS
(
SELECT sale_date, SUM(total) AS tot_per_giorno
FROM sales_staging
WHERE sale_date LIKE '2023-1%'
GROUP BY sale_date
ORDER BY sale_date
)
SELECT SUM(tot_per_giorno) OVER() AS tot_Q4_2023
FROM tot_giornaliero
;

# Il totale è 1.963.300

-- PROBLEMA 3: E se volessimo trovare il ricavo totale dell'ultimo trimestre del 2023 per ogni città?

SELECT *
FROM customers;
SELECT *
FROM city;
SELECT *
FROM sales_staging
WHERE sale_date LIKE '2023-1%';

SELECT customers.customer_id, customer_name, customers.city_id, city_name, sales_staging.sale_date, sales_staging.total 
FROM customers
LEFT JOIN city ON customers.city_id = city.city_id
LEFT JOIN sales_staging ON sales_staging.customer_id = customers.customer_id
WHERE sale_date LIKE '2023-1%';

WITH vendite_per_citta AS
(
SELECT customers.customer_id, customer_name, customers.city_id, city_name, sales_staging.sale_date, sales_staging.total 
FROM customers
LEFT JOIN city ON customers.city_id = city.city_id
LEFT JOIN sales_staging ON sales_staging.customer_id = customers.customer_id
WHERE sale_date LIKE '2023-1%'
)
SELECT city_id, city_name, SUM(total) AS ricavato_tot
FROM vendite_per_citta
GROUP BY city_id, city_name
ORDER BY ricavato_tot DESC;

# Le 5 città in cui l'azienda ha fatturato di più nell'ultimo trimestre del 2023 sono (in ordine decrescente): Pune, Chennai, Bangalore, Jaipur e Delhi.

-- PROBLEMA 4: Importo medio delle vendite per città
# Qual è l'importo medio delle vendite per cliente in ciascuna città?
# Devo calcolare il numero di clienti in ogni città e il ricavato totale di ogni città. Il risultato voluto sarà dato dal ricavato totale/numero di clienti per città.

SELECT *
FROM customers;
SELECT *
FROM city;
SELECT *
FROM sales_staging;

# Numero totale di clienti per città
SELECT city_id, COUNT(city_id) AS custom_per_city
FROM customers
GROUP BY city_id;

# Ricavato totale delle vendite in ogni città
SELECT city_id, SUM(total) AS sales_per_city
FROM sales_staging s
LEFT JOIN customers c ON c.customer_id = s.customer_id
GROUP BY city_id;

CREATE TEMPORARY TABLE total_cust
(
	city_id INT PRIMARY KEY,
    custom_per_city INT
);
INSERT INTO total_cust
SELECT city_id, COUNT(city_id) AS custom_per_city
FROM customers
GROUP BY city_id;

SELECT *
FROM total_cust;

CREATE TEMPORARY TABLE total_sales
(
	city_id INT PRIMARY KEY,
    sales_per_city INT
);
INSERT INTO total_sales
SELECT city_id, SUM(total) AS sales_per_city
FROM sales_staging s
LEFT JOIN customers c ON c.customer_id = s.customer_id
GROUP BY city_id;

SELECT *
FROM total_sales;

SELECT s.city_id, city_name, ROUND((sales_per_city/custom_per_city),2) AS avg_sales_per_cust_per_city
FROM total_sales s
LEFT JOIN total_cust c ON s.city_id = c.city_id
LEFT JOIN city_staging ON city_staging.city_id = s.city_id
ORDER BY avg_sales_per_cust_per_city DESC;

# La spesa media per cliente in ciascuna città è più alta in (ordine decrescente): Pune, Chennai, Bangalore, Jaipur e Delhi.


-- PROBLEMA 5: Numero di vendite per prodotto
# Quante unità sono state vendute per ogni tipo di caffè?

SELECT *
FROM sales_staging;
SELECT *
FROM products;

SELECT p.product_id, p.product_name, COUNT(s.product_id) AS sales_per_product
FROM sales_staging s
LEFT JOIN products p ON p.product_id = s.product_id 
GROUP BY p.product_id, p.product_name
ORDER BY sales_per_product DESC;

# Possiamo consigliare i primi 10 prodotti più venduti come prodotti da vendere nei nuovi negozi che apriranno. 


-- PROBLEMA 6: Popolazione urbana e consumatori di caffè
# Mostra un elenco di città con il numero di abitanti e la stima dei consumatori di caffè.
# L'avevamo già creata al punto 1. Aggiungiamo una ulteriore colonna contenente i clienti attuali.

WITH tot_current_cust AS
(
SELECT city_id, COUNT(city_id) AS curr_custom
FROM customers
GROUP BY city_id
)
SELECT c.city_name, c.population, curr_custom, c.estimated_consumers
FROM city_staging2 c
RIGHT JOIN tot_current_cust ON c.city_id = tot_current_cust.city_id;


-- PROBLEMA 7: Classifica vendite per città
# Quali sono i primi 3 prodotti per volume di vendita in ogni città?

CREATE TEMPORARY TABLE vendite_per_citta 
(
	WITH tot_vendite AS 
	(
	SELECT customer_id, product_id, COUNT(product_id) AS vendite_tot
	FROM sales_staging
	GROUP BY product_id, customer_id
	ORDER BY product_id, customer_id
	),
	nome_citta AS
	(
	SELECT customer_id, city_name
	FROM customers
	LEFT JOIN city_staging ON customers.city_id = city_staging.city_id
	)
	SELECT city_name, products.product_id, products.product_name, SUM(vendite_tot) AS totale_vendite
	FROM tot_vendite
	LEFT JOIN nome_citta ON tot_vendite.customer_id = nome_citta.customer_id
	LEFT JOIN products ON products.product_id = tot_vendite.product_id
	GROUP BY city_name, products.product_id, products.product_name
);

WITH table1 AS
(
SELECT city_name, product_name, totale_vendite,
DENSE_RANK() OVER(PARTITION BY city_name ORDER BY totale_vendite DESC) AS classifica
FROM vendite_per_citta
)
SELECT city_name, product_name, totale_vendite, classifica
FROM table1
WHERE classifica <= 3
;


-- PROBLEMA 8: Segmentazione dei clienti per città
# Quanti clienti unici ci sono in ciascuna città che hanno acquistato almeno un prodotto?
WITH tab1 AS
(
SELECT s.customer_id, c.city_name
FROM sales s
LEFT JOIN customers cust ON cust.customer_id = s.customer_id
LEFT JOIN city c ON cust.city_id = c.city_id
GROUP BY s.customer_id, c.city_name
)
SELECT city_name, COUNT(city_name)
FROM tab1
GROUP BY city_name;


-- PROBLEMA 9: Quanti clienti in ciascuna città hanno acquistato almeno un prodotto a base di caffe?
SELECT *
FROM products;
# Da questa tabella si vede che i prodotti a base di caffe sono quelli con id da 1 a 14

SELECT city_name, COUNT(DISTINCT customer_id)
FROM (
	SELECT city.city_name, customers.customer_id, sales.product_id
	FROM city
	LEFT JOIN customers ON city.city_id = customers.city_id
	LEFT JOIN sales ON sales.customer_id = customers.customer_id
	WHERE product_id <= 14
    ) AS tab_temp
GROUP BY city_name;
    

-- PROBLEMA 10: Confronto media vendite e affitto per città
# Per ogni città, calcola il valore medio delle vendite e dell'affitto riferito al singolo cliente.

# La spesa media per cliente è data dal totale del fatturato delle vendite di una città diviso il numero di clienti unici in quella città. 
# Il costo medio dell'affitto per cliente è dato dal costo totale dell'affitto dei locali per quella città diviso il numero di clienti unici di quella città.

WITH fatturato_per_citta AS
(
	SELECT customers.city_id, city_name, SUM(sales_staging.total) AS fatturato
	FROM customers
	LEFT JOIN city_staging ON customers.city_id = city_staging.city_id
	LEFT JOIN sales_staging ON sales_staging.customer_id = customers.customer_id
	GROUP BY city_id, city_name
	ORDER BY fatturato DESC
), 
clienti_unici AS
(
	WITH tab1 AS
	(
	SELECT s.customer_id, c.city_name
	FROM sales s
	LEFT JOIN customers cust ON cust.customer_id = s.customer_id
	LEFT JOIN city c ON cust.city_id = c.city_id
	GROUP BY s.customer_id, c.city_name
	)
	SELECT city_name, COUNT(city_name) AS cl_unici
	FROM tab1
	GROUP BY city_name
)
SELECT fatturato_per_citta.city_name, cl_unici, fatturato, estimated_rent,
ROUND((fatturato/cl_unici),2) AS spesa_media_per_cliente, 
ROUND((estimated_rent/cl_unici),2) AS costo_medio_affitto_per_cl
FROM fatturato_per_citta
LEFT JOIN clienti_unici ON fatturato_per_citta.city_name = clienti_unici.city_name
LEFT JOIN city ON city.city_name = clienti_unici.city_name
ORDER BY 5 DESC;

# Nelle città di Pune, Chennai e Bangalore l'entrata dalle vendite è parecchio più alta rispetto all'affitto dei locali, quindi potrebbero essere delle valide scelte in cui aprire nuovi store.

-- PROBLEMA 11: Tasso di crescita vendite mensili
# Calcola la variazione percentuale mensile del fatturato per evidenziare la crescita o il calo delle vendite per ogni città.

WITH vendite_mensili AS
(
SELECT DATE_FORMAT(sale_date, '%Y-%m') AS mese,
	SUM(total) AS totale_vendite    
FROM sales_staging
GROUP BY DATE_FORMAT(sale_date, '%Y-%m')
ORDER BY mese
)
SELECT mese, totale_vendite, ROUND((totale_vendite - LAG(totale_vendite,1) OVER (ORDER BY mese))/LAG(totale_vendite,1) OVER (ORDER BY mese) * 100,2) AS variazione_percentuale_mensile
FROM vendite_mensili;

WITH vendite_mensili_per_citta AS 
	(
		SELECT DATE_FORMAT(sale_date, '%Y-%m') AS mese, city_name, SUM(total) AS totale_vendite
		FROM sales_staging s
		LEFT JOIN customers c ON c.customer_id=s.customer_id
		LEFT JOIN city ON city.city_id=c.city_id
		GROUP BY DATE_FORMAT(sale_date, '%Y-%m'), city_name
		ORDER BY 2,1
		)
	SELECT mese, city_name,
		ROUND((totale_vendite - LAG(totale_vendite,1) OVER (PARTITION BY city_name ORDER BY mese))/LAG(totale_vendite,1) OVER (PARTITION BY city_name ORDER BY mese) * 100,2) AS variazione_percentuale_mensile
	FROM vendite_mensili_per_citta
	ORDER BY 2,1;
    

-- PROBLEMA 12: Analisi del potenziale di mercato
# Identifica le prime 3 città in base alle vendite più elevate; 
# restituisci il nome della città, le vendite totali, l'affitto totale, i clienti totali e la stima dei consumatori di caffè.

WITH vendite_totali AS
(
	SELECT city_name, SUM(total) AS vendite_totali
	FROM sales_staging s
	LEFT JOIN customers c ON c.customer_id=s.customer_id
	LEFT JOIN city ON city.city_id=c.city_id
	GROUP BY city_name
	ORDER BY 2 DESC
    LIMIT 3
),
clienti_tot AS
(
SELECT city_name, COUNT(c.city_id) AS clienti_totali, estimated_rent
FROM customers c
LEFT JOIN city ON c.city_id=city.city_id
GROUP BY city_name, estimated_rent
),
consumatori_stimati AS
(
SELECT city_name, (population*0.25) AS estimated_consumers
FROM city
)
SELECT v.city_name, v.vendite_totali, c.estimated_rent, c.clienti_totali, consumatori_stimati.estimated_consumers
FROM vendite_totali v
LEFT JOIN clienti_tot c ON c.city_name=v.city_name
LEFT JOIN consumatori_stimati ON consumatori_stimati.city_name=v.city_name;

#Le prime 3 città con le vendite più elevate sono: Pune, Chennai e Bangalore. 















