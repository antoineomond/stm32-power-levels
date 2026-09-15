/* USER CODE BEGIN Header */
/**
  ******************************************************************************
  * @file           : main.c
  * @brief          : Main program body
  ******************************************************************************
  * @attention
  *
  * Copyright (c) 2026 STMicroelectronics.
  * All rights reserved.
  *
  * This software is licensed under terms that can be found in the LICENSE file
  * in the root directory of this software component.
  * If no LICENSE file comes with this software, it is provided AS-IS.
  *
  ******************************************************************************
  */
/* USER CODE END Header */
/* Includes ------------------------------------------------------------------*/
#include "main.h"

/* Private includes ----------------------------------------------------------*/
/* USER CODE BEGIN Includes */
#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>

#define PRINT_BENCH_RES 1

// Benchmark sizes
#define BENCH_PRIME_SIZE 50000
#define BENCH_MAT_SIZE 10500
#define NB_ITERATIONS_MAT_MUL 2000

// Benchmark correct results
#define CORRECT_PRIME 669
#define CORRECT_MAT_MUL 1073741824
#define CORRECT_MAT_MUL_FLOAT_UPPER 0.525 
#define CORRECT_MAT_MUL_FLOAT_LOWER 0.524 

// Constants
const uint32_t US = 1000000;
const uint32_t RESET_VAL = 0xDEADBEEF; 

/* USER CODE END Includes */

/* Private typedef -----------------------------------------------------------*/
/* USER CODE BEGIN PTD */

/* USER CODE END PTD */

/* Private define ------------------------------------------------------------*/
/* USER CODE BEGIN PD */

/* USER CODE END PD */

/* Private macro -------------------------------------------------------------*/
/* USER CODE BEGIN PM */

/* USER CODE END PM */

/* Private variables ---------------------------------------------------------*/

/* USER CODE BEGIN PV */

/* USER CODE END PV */

/* Private function prototypes -----------------------------------------------*/
void SystemClock_Config(void);
static void MX_GPIO_Init(void);
/* USER CODE BEGIN PFP */
//#ifdef __GNUC__
//#define PUTCHAR_PROTOTYPE int __io_putchar(int ch)
//#else
//#define PUTCHAR_PROTOTYPE int fputc(int ch, FILE *f)
//#endif
//
//PUTCHAR_PROTOTYPE
//{
//  HAL_UART_Transmit(&huart1, (uint8_t *)&ch, 1, HAL_MAX_DELAY);
//  return ch;
//}
/* USER CODE END PFP */

/* Private user code ---------------------------------------------------------*/
/* USER CODE BEGIN 0 */
uint32_t compute_primes(uint32_t start, uint32_t end) {
	volatile uint32_t cpt = 0;
	uint32_t is_prime = 1;
	for (int k = start; k < end; k++) {
		is_prime = 1;
		for (int i = 2; i	< k; i++) {
			if (k%i==0) {
				is_prime = 0;
			}
		}
		if(is_prime == 1) {
			cpt += 1;
		}
	}
	return cpt;
}

uint8_t benchmark_prime(uint32_t benchmark_size) {
	volatile uint32_t cpt = compute_primes(2, benchmark_size);
	uint8_t correct = 1;
	if(cpt != CORRECT_PRIME) {
		correct = 0;
	}
	return correct;
}

uint8_t benchmark_mat_mul(uint32_t benchmark_size, uint32_t nb_iteration_mat_mul) {
	uint32_t A_value = 1UL<<15;
	uint32_t B_value = 1UL<<15;
	volatile uint8_t correct = 1;
	for (int k = 0; k < nb_iteration_mat_mul; k++) {
		// Three 32-bits matrixes of 72 elements account for 486 kB, which should account for all 8 memory banks in SRAM0 and SRAM1
		uint32_t *A = malloc(sizeof(uint32_t)*benchmark_size);
		uint32_t *B = malloc(sizeof(uint32_t)*benchmark_size);
		uint32_t *C = malloc(sizeof(uint32_t)*benchmark_size);
		for (int i = 0; i < benchmark_size; i++) {
			A[i] = A_value;
			B[i] = B_value;
			//printf("B[i] %d\n", B[i]);
		}
		for (int i = 0; i < benchmark_size; i++) {
			C[i] = A[i] * B[i];
		}
		free(A);
		free(B);
		free(C);
	}
	return correct;
}

uint8_t benchmark_mat_mul_float(uint32_t benchmark_size, uint32_t nb_iteration_mat_mul) {
	float A_value = 1.23456789;
	float B_value = 1.23456789;
	volatile uint8_t correct = 1;
	for (int k = 0; k < nb_iteration_mat_mul; k++) {
		// Three 32-bits matrixes of 72 elements account for 486 kB, which should account for all 8 memory banks in SRAM0 and SRAM1
		float *A = malloc(sizeof(float)*benchmark_size);
		float *B = malloc(sizeof(float)*benchmark_size);
		float *C = malloc(sizeof(float)*benchmark_size);
		for (int i = 0; i < benchmark_size; i++) {
			A[i] = A_value;
			B[i] = B_value;
		}
		for (int i = 0; i < benchmark_size; i++) {
			C[i] = A[i] * B[i] - 1;
		}
		// Verification
		for (int i = 0; i < benchmark_size; i++) {
			if(C[i] > CORRECT_MAT_MUL_FLOAT_UPPER || C[i] < CORRECT_MAT_MUL_FLOAT_LOWER) {
				correct = 0;
			}
		}
		free(A);
		free(B);
		free(C);
	}
	return correct;
}

uint8_t benchmark_mat_mul_double(uint32_t benchmark_size, uint32_t nb_iteration_mat_mul) {
	double A_value = 1.23456789;
	double B_value = 1.23456789;
	volatile uint8_t correct = 1;
	for (int k = 0; k < nb_iteration_mat_mul; k++) {
		// Three 32-bits matrixes of 72 elements account for 486 kB, which should account for all 8 memory banks in SRAM0 and SRAM1
		double *A = malloc(sizeof(double)*benchmark_size);
		double *B = malloc(sizeof(double)*benchmark_size);
		double *C = malloc(sizeof(double)*benchmark_size);
		for (int i = 0; i < benchmark_size; i++) {
			A[i] = A_value;
			B[i] = B_value;
		}
		for (int i = 0; i < benchmark_size; i++) {
			C[i] = A[i] * B[i] - 1;
		}
		// Verification
		for (int i = 0; i < benchmark_size; i++) {
			if(C[i] > CORRECT_MAT_MUL_FLOAT_UPPER || C[i] < CORRECT_MAT_MUL_FLOAT_LOWER) {
				correct = 0;
			}
		}
		free(A);
		free(B);
		free(C);
	}
	return correct;
}


void run_benchmarks() {
	// Wait 10s after having apply conf (HAL_Delay is noop so active wait)
	HAL_Delay(2000);
	
	// prime
	//HAL_GPIO_WritePin(GPIOA, GPIO_PIN_5, 1);
	//uint32_t res_prime = benchmark_prime(BENCH_PRIME_SIZE);
	//HAL_GPIO_WritePin(GPIOA, GPIO_PIN_5, 0);
	//HAL_Delay(100);
	
	// mat mul
	//HAL_GPIO_WritePin(GPIOA, GPIO_PIN_5, 1);
	//uint32_t res_mat_mul = benchmark_mat_mul(BENCH_MAT_SIZE, NB_ITERATIONS_MAT_MUL);
	//HAL_GPIO_WritePin(GPIOA, GPIO_PIN_5, 0);
	//HAL_Delay(100);
	
	//return;
	
	// mat mul float
	HAL_GPIO_WritePin(GPIOA, GPIO_PIN_5, 1);
	uint32_t res_mat_mul_float = benchmark_mat_mul_float(BENCH_MAT_SIZE, NB_ITERATIONS_MAT_MUL);
	HAL_GPIO_WritePin(GPIOA, GPIO_PIN_5, 0);
	HAL_Delay(100);
	
	// mat mul double
	//HAL_GPIO_WritePin(GPIOA, GPIO_PIN_5, 1);
	//uint32_t res_mat_mul_double = benchmark_mat_mul_double(BENCH_MAT_SIZE/2, NB_ITERATIONS_MAT_MUL);
	//HAL_GPIO_WritePin(GPIOA, GPIO_PIN_5, 0);
	//HAL_Delay(100);
	
	return;
	
	#if PRINT_BENCH_RES
	//printf("benchmark_prime: %d \n", res_prime);
	//printf("benchmark_mat_mul: %d \n", res_mat_mul);
	//printf("benchmark_mat_mul_float: %d \n", res_mat_mul_float);
	//printf("benchmark_mat_mul_double: %d \n", res_mat_mul_double);
	#endif
}

/* USER CODE END 0 */

/**
  * @brief  The application entry point.
  * @retval int
  */
int main(void)
{

  /* USER CODE BEGIN 1 */

  /* USER CODE END 1 */

  /* MCU Configuration--------------------------------------------------------*/

  /* Reset of all peripherals, Initializes the Flash interface and the Systick. */
  HAL_Init();

  /* USER CODE BEGIN Init */

  /* USER CODE END Init */

  /* Configure the system clock */
  SystemClock_Config();

  /* USER CODE BEGIN SysInit */

  /* USER CODE END SysInit */

  /* Initialize all configured peripherals */
  MX_GPIO_Init();
  /* USER CODE BEGIN 2 */
	__HAL_FLASH_PREFETCH_BUFFER_DISABLE();
	__HAL_FLASH_INSTRUCTION_CACHE_DISABLE();
	__HAL_FLASH_DATA_CACHE_DISABLE();
	//__HAL_FLASH_PREFETCH_BUFFER_ENABLE();
	//__HAL_FLASH_INSTRUCTION_CACHE_ENABLE();
	//__HAL_FLASH_DATA_CACHE_ENABLE();
	//printf("test\n");
	while(1){
		run_benchmarks();
		//uint32_t hclk_freq = HAL_RCC_GetHCLKFreq();
		//printf("hclk_freq: %d\n", hclk_freq); 
		//uint32_t pclk1_freq = HAL_RCC_GetPCLK1Freq();
		//printf("pclk1_freq: %d\n", pclk1_freq); 
		//uint32_t pclk2_freq = HAL_RCC_GetPCLK2Freq();
		//printf("pclk2_freq: %d\n", pclk2_freq); 
		//printf("\n");
		//HAL_Delay(1000);
	}
	
	run_benchmarks();
	__HAL_PWR_VOLTAGESCALING_CONFIG(PWR_REGULATOR_VOLTAGE_SCALE2);
	run_benchmarks();
	__HAL_PWR_VOLTAGESCALING_CONFIG(PWR_REGULATOR_VOLTAGE_SCALE3);
	run_benchmarks();
  /* USER CODE END 2 */

  /* Infinite loop */
  /* USER CODE BEGIN WHILE */
  while (1)
  {
		//HAL_GPIO_WritePin(GPIOC, GPIO_PIN_13, 0);
		//HAL_Delay(2000);
		//HAL_GPIO_WritePin(GPIOC, GPIO_PIN_13, 1);

  }
    /* USER CODE END WHILE */

    /* USER CODE BEGIN 3 */
  /* USER CODE END 3 */
}

/**
  * @brief System Clock Configuration
  * @retval None
  */
void SystemClock_Config(void)
{
  RCC_OscInitTypeDef RCC_OscInitStruct = {0};
  RCC_ClkInitTypeDef RCC_ClkInitStruct = {0};

  /** Configure the main internal regulator output voltage
  */
  __HAL_RCC_PWR_CLK_ENABLE();
  __HAL_PWR_VOLTAGESCALING_CONFIG(PWR_REGULATOR_VOLTAGE_SCALE3);

  /** Initializes the RCC Oscillators according to the specified parameters
  * in the RCC_OscInitTypeDef structure.
  */
  RCC_OscInitStruct.OscillatorType = RCC_OSCILLATORTYPE_HSI;
  RCC_OscInitStruct.HSIState = RCC_HSI_ON;
  RCC_OscInitStruct.HSICalibrationValue = RCC_HSICALIBRATION_DEFAULT;
  RCC_OscInitStruct.PLL.PLLState = RCC_PLL_OFF;
  if (HAL_RCC_OscConfig(&RCC_OscInitStruct) != HAL_OK)
  {
    Error_Handler();
  }

  /** Initializes the CPU, AHB and APB buses clocks
  */
  RCC_ClkInitStruct.ClockType = RCC_CLOCKTYPE_HCLK|RCC_CLOCKTYPE_SYSCLK
                              |RCC_CLOCKTYPE_PCLK1|RCC_CLOCKTYPE_PCLK2;
  RCC_ClkInitStruct.SYSCLKSource = RCC_SYSCLKSOURCE_HSI;
  RCC_ClkInitStruct.AHBCLKDivider = RCC_SYSCLK_DIV16;
  RCC_ClkInitStruct.APB1CLKDivider = RCC_HCLK_DIV2;
  RCC_ClkInitStruct.APB2CLKDivider = RCC_HCLK_DIV1;

  if (HAL_RCC_ClockConfig(&RCC_ClkInitStruct, FLASH_LATENCY_3) != HAL_OK)
  {
    Error_Handler();
  }
}

/**
  * @brief GPIO Initialization Function
  * @param None
  * @retval None
  */
static void MX_GPIO_Init(void)
{
  GPIO_InitTypeDef GPIO_InitStruct = {0};
  /* USER CODE BEGIN MX_GPIO_Init_1 */

  /* USER CODE END MX_GPIO_Init_1 */

  /* GPIO Ports Clock Enable */
  __HAL_RCC_GPIOC_CLK_ENABLE();
  __HAL_RCC_GPIOH_CLK_ENABLE();
  __HAL_RCC_GPIOA_CLK_ENABLE();
  __HAL_RCC_GPIOB_CLK_ENABLE();

  /*Configure GPIO pins : PC13 PC14 PC15 */
  GPIO_InitStruct.Pin = GPIO_PIN_13|GPIO_PIN_14|GPIO_PIN_15;
  GPIO_InitStruct.Mode = GPIO_MODE_INPUT;
  GPIO_InitStruct.Pull = GPIO_PULLDOWN;
  HAL_GPIO_Init(GPIOC, &GPIO_InitStruct);

  /*Configure GPIO pins : PH0 PH1 */
  GPIO_InitStruct.Pin = GPIO_PIN_0|GPIO_PIN_1;
  GPIO_InitStruct.Mode = GPIO_MODE_INPUT;
  GPIO_InitStruct.Pull = GPIO_PULLDOWN;
  HAL_GPIO_Init(GPIOH, &GPIO_InitStruct);

  /*Configure GPIO pins : PA0 PA1 PA2 PA3
                           PA4 PA5 PA6 PA7
                           PA8 PA9 PA10 PA11
                           PA12 PA13 PA14 PA15 */
  GPIO_InitStruct.Pin = GPIO_PIN_0|GPIO_PIN_1|GPIO_PIN_2|GPIO_PIN_3
                          |GPIO_PIN_4|GPIO_PIN_5|GPIO_PIN_6|GPIO_PIN_7
                          |GPIO_PIN_8|GPIO_PIN_9|GPIO_PIN_10|GPIO_PIN_11
                          |GPIO_PIN_12|GPIO_PIN_13|GPIO_PIN_14|GPIO_PIN_15;
  GPIO_InitStruct.Mode = GPIO_MODE_INPUT;
  GPIO_InitStruct.Pull = GPIO_PULLDOWN;
  HAL_GPIO_Init(GPIOA, &GPIO_InitStruct);

  /*Configure GPIO pins : PB0 PB1 PB2 PB10
                           PB12 PB13 PB14 PB15
                           PB3 PB4 PB5 PB6
                           PB7 PB8 PB9 */
  GPIO_InitStruct.Pin = GPIO_PIN_0|GPIO_PIN_1|GPIO_PIN_2|GPIO_PIN_10
                          |GPIO_PIN_12|GPIO_PIN_13|GPIO_PIN_14|GPIO_PIN_15
                          |GPIO_PIN_3|GPIO_PIN_4|GPIO_PIN_5|GPIO_PIN_6
                          |GPIO_PIN_7|GPIO_PIN_8|GPIO_PIN_9;
  GPIO_InitStruct.Mode = GPIO_MODE_INPUT;
  GPIO_InitStruct.Pull = GPIO_PULLDOWN;
  HAL_GPIO_Init(GPIOB, &GPIO_InitStruct);

  /* USER CODE BEGIN MX_GPIO_Init_2 */
  //GPIO_InitStruct.Pin = GPIO_PIN_13;
  //GPIO_InitStruct.Mode = GPIO_MODE_INPUT;
  //GPIO_InitStruct.Pull = GPIO_PULLUP;
  //HAL_GPIO_Init(GPIOC, &GPIO_InitStruct);

  /* USER CODE END MX_GPIO_Init_2 */
}

/* USER CODE BEGIN 4 */

/* USER CODE END 4 */

/**
  * @brief  This function is executed in case of error occurrence.
  * @retval None
  */
void Error_Handler(void)
{
  /* USER CODE BEGIN Error_Handler_Debug */
  /* User can add his own implementation to report the HAL error return state */
  __disable_irq();
  while (1)
  {
  }
  /* USER CODE END Error_Handler_Debug */
}
#ifdef USE_FULL_ASSERT
/**
  * @brief  Reports the name of the source file and the source line number
  *         where the assert_param error has occurred.
  * @param  file: pointer to the source file name
  * @param  line: assert_param error line source number
  * @retval None
  */
void assert_failed(uint8_t *file, uint32_t line)
{
  /* USER CODE BEGIN 6 */
  /* User can add his own implementation to report the file name and line number,  */
  /* USER CODE END 6 */
}
#endif /* USE_FULL_ASSERT */
